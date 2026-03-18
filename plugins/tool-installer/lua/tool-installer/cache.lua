local M = {}

local cache_path = vim.fn.stdpath("cache") .. "/tool-installer.json"

---@class tool-installer.CacheEntry
---@field found boolean
---@field ts integer

---@type table<string, tool-installer.CacheEntry>?
local _tools
local _dirty = false

local function load()
  if _tools then
    return _tools
  end
  local f = io.open(cache_path)
  if f then
    local ok, data = pcall(vim.json.decode, f:read("*a"))
    f:close()
    if ok and type(data) == "table" and type(data.tools) == "table" then
      _tools = data.tools
      return _tools
    end
  end
  _tools = {}
  return _tools
end

--- Check if a tool binary is available (cached or live check).
---@param bin string
---@param ttl integer
---@return boolean
function M.is_available(bin, ttl)
  local tools = load()
  local entry = tools[bin]
  local now = os.time()

  -- Cached true within TTL — skip executable check
  if entry and entry.found and (now - entry.ts) < ttl then
    return true
  end

  -- Re-verify (expired, cached false from previous session, or uncached)
  local found = vim.fn.executable(bin) == 1
  if not entry or entry.found ~= found then
    tools[bin] = { found = found, ts = now }
    _dirty = true
  else
    entry.ts = now
  end
  return found
end

--- Mark a tool as found in the cache.
---@param bin string
---@param found boolean
function M.set(bin, found)
  local tools = load()
  tools[bin] = { found = found, ts = os.time() }
  _dirty = true
end

--- Return cache stats for health checks.
---@return { path: string, count: integer }
function M.stats()
  local tools = load()
  return { path = cache_path, count = vim.tbl_count(tools) }
end

--- Clear all cached entries (in-memory and on disk).
function M.clear()
  _tools = {}
  _dirty = false
  os.remove(cache_path)
end

--- Write cache to disk if dirty.
function M.flush()
  if not _dirty or not _tools then
    return
  end
  local f = io.open(cache_path, "w")
  if f then
    f:write(vim.json.encode({ tools = _tools }))
    f:close()
    _dirty = false
  end
end

-- Flush on exit
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = M.flush,
})

return M
