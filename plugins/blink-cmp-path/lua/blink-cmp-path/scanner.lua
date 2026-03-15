--- Backend abstraction for file discovery.
--- Supports git ls-files (primary), fd (fallback), and glob scanning
--- for always_index patterns.

local M = {}

--- Parse null-separated output into a list of bare relative paths.
--- Strips leading `./` that tools like fd emit.
---@param stdout string
---@return string[]
local function parse_null_separated(stdout)
  local paths = {}
  for path in stdout:gmatch("[^%z]+") do
    if path:sub(1, 2) == "./" then
      path = path:sub(3)
    end
    paths[#paths + 1] = path
  end
  return paths
end

--- Spawn `git ls-files -co --exclude-standard -z` in the given directory.
---@param cwd string
---@param callback fun(paths: string[])
---@return fun() cancel
function M.scan_git(cwd, callback)
  local job = vim.system(
    { "git", "ls-files", "-co", "--exclude-standard", "-z" },
    { cwd = cwd, text = true },
    function(result)
      vim.schedule(function()
        if result.code ~= 0 or not result.stdout then
          return callback({})
        end
        callback(parse_null_separated(result.stdout))
      end)
    end
  )
  return function()
    job:kill()
  end
end

--- Spawn `fd --type f --hidden --exclude .git --print0` as fallback.
---@param cwd string
---@param callback fun(paths: string[])
---@return fun() cancel
function M.scan_fd(cwd, callback)
  local job = vim.system(
    { "fd", "--type", "f", "--hidden", "--exclude", ".git", "--print0" },
    { cwd = cwd, text = true },
    function(result)
      vim.schedule(function()
        if result.code ~= 0 or not result.stdout then
          return callback({})
        end
        callback(parse_null_separated(result.stdout))
      end)
    end
  )
  return function()
    job:kill()
  end
end

--- Scan always_index glob patterns asynchronously via coroutine.
--- Yields periodically to avoid blocking the event loop.
---@param cwd string
---@param patterns string[]
---@param callback fun(paths: string[])
function M.scan_glob(cwd, patterns, callback)
  local co = coroutine.create(function()
    local paths = {}
    local prefix_len = #cwd + 2
    for _, pattern in ipairs(patterns) do
      local matches = vim.fn.globpath(cwd, pattern, false, true)
      for j, abs in ipairs(matches) do
        local stat = vim.uv.fs_stat(abs)
        if stat and stat.type == "file" then
          paths[#paths + 1] = abs:sub(prefix_len)
        end
        -- Yield every 50 files to let the event loop breathe
        if j % 50 == 0 then
          coroutine.yield()
        end
      end
    end
    return paths
  end)

  local function step()
    local ok, result = coroutine.resume(co)
    if not ok then
      callback({})
    elseif coroutine.status(co) == "dead" then
      callback(result)
    else
      vim.schedule(step)
    end
  end
  vim.schedule(step)
end

--- Detect which backend to use for the given directory.
---@param cwd string
---@return "git"|"fd"|"walk"
function M.detect_backend(cwd)
  if vim.uv.fs_stat(cwd .. "/.git") then
    return "git"
  end
  if vim.fn.executable("fd") == 1 then
    return "fd"
  end
  return "walk"
end

return M
