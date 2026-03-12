local M = {}

---@class lib.tools.Tool
---@field name string
---@field bin string
---@field kind string

local CACHE_TTL = 3600 -- 1 hour
local cache_path = vim.fn.stdpath("cache") .. "/tool-check.json"
local _cache ---@type table<string, boolean>?
local _cache_dirty = false

local function load_cache()
  if _cache then
    return _cache
  end
  local f = io.open(cache_path)
  if f then
    local ok, data = pcall(vim.json.decode, f:read("*a"))
    f:close()
    if ok and data and data.ts and (os.time() - data.ts) < CACHE_TTL then
      _cache = data.bins or {}
      return _cache
    end
  end
  _cache = {}
  return _cache
end

local function save_cache()
  if not _cache_dirty then
    return
  end
  local f = io.open(cache_path, "w")
  if f then
    f:write(vim.json.encode({ ts = os.time(), bins = _cache }))
    f:close()
    _cache_dirty = false
  end
end

local function is_executable(bin)
  local cache = load_cache()
  if cache[bin] ~= nil then
    return cache[bin]
  end
  local result = vim.fn.executable(bin) == 1
  cache[bin] = result
  _cache_dirty = true
  return result
end

local function missing_tools(tools)
  local missing = {}
  for _, t in ipairs(tools) do
    if not is_executable(t.bin) then
      table.insert(
        missing,
        string.format("  %s (%s): %s", t.kind, t.name, t.bin)
      )
    end
  end
  save_cache()
  return missing
end

local function notify_missing(tools)
  local missing = missing_tools(tools)
  if #missing == 0 then
    return
  end

  vim.notify(
    "Missing tools:\n" .. table.concat(missing, "\n"),
    vim.log.levels.WARN
  )
end

--- Check tool binaries when a matching filetype is first opened.
--- @param ft string|string[] filetype(s) to trigger the check
--- @param tools lib.tools.Tool[]
function M.check(ft, tools)
  local group = vim.api.nvim_create_augroup(
    "ToolCheck_" .. (type(ft) == "table" and ft[1] or ft),
    {}
  )
  vim.api.nvim_create_autocmd("FileType", {
    pattern = ft,
    group = group,
    once = true,
    callback = function()
      notify_missing(tools)
    end,
  })
end

--- Check tool binaries on next event-loop tick (non-blocking).
--- @param tools lib.tools.Tool[]
function M.check_now(tools)
  vim.schedule(function()
    notify_missing(tools)
  end)
end

return M
