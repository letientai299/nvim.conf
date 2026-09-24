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

--- Walk extra paths without blocking input.
---@param cwd string
---@param patterns string[]
---@param callback fun(paths: string[])
---@param exclude_dirs? string[]
---@return fun() cancel
function M.scan_glob(cwd, patterns, callback, exclude_dirs)
  local cancelled = false
  local excluded = {}
  for _, name in ipairs(exclude_dirs or {}) do
    excluded[name] = true
  end
  local matchers, queue, seen, paths = {}, {}, {}, {}
  for _, pattern in ipairs(patterns) do
    matchers[#matchers + 1] = vim.glob.to_lpeg(pattern)
    local wildcard = pattern:find("[*?%[{\\]")
    local prefix = wildcard and pattern:sub(1, wildcard - 1) or pattern
    local root = prefix:match("^(.*)/") or ""
    if not seen[root] then
      seen[root] = true
      queue[#queue + 1] = root
    end
  end

  local function add_file(rel)
    for _, matcher in ipairs(matchers) do
      if matcher:match(rel) then
        paths[#paths + 1] = rel
        return
      end
    end
  end

  local next_dir
  local position = 0
  next_dir = function()
    if cancelled then
      return
    end
    position = position + 1
    local dir = queue[position]
    if not dir then
      callback(paths)
      return
    end
    vim.uv.fs_scandir(cwd .. "/" .. dir, function(_, entries)
      vim.schedule(function()
        if cancelled then
          return
        end
        if not entries then
          next_dir()
          return
        end
        local read_entries
        read_entries = function()
          if cancelled then
            return
          end
          for _ = 1, 128 do
            local name, kind = vim.uv.fs_scandir_next(entries)
            if not name then
              next_dir()
              return
            end
            local rel = dir == "" and name or dir .. "/" .. name
            if kind == "directory" then
              if not excluded[name] and not seen[rel] then
                seen[rel] = true
                queue[#queue + 1] = rel
              end
            elseif kind == "file" then
              add_file(rel)
            elseif kind == "link" then
              vim.uv.fs_stat(cwd .. "/" .. rel, function(_, stat)
                vim.schedule(function()
                  if cancelled then
                    return
                  end
                  if stat and stat.type == "file" then
                    add_file(rel)
                  end
                  read_entries()
                end)
              end)
              return
            end
          end
          vim.schedule(read_entries)
        end
        read_entries()
      end)
    end)
  end
  vim.schedule(next_dir)
  return function()
    cancelled = true
  end
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
