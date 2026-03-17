local fallback_config = require("lib.fallback_config")

local M = {}

--- Prettier config file names for project detection.
--- Does not include package.json (needs content inspection) — prettier's own
--- config discovery handles that case when cwd points to the project root.
--- @type FallbackSpec
M.fallback_spec = {
  names = {
    ".prettierrc",
    ".prettierrc.json",
    ".prettierrc.yml",
    ".prettierrc.yaml",
    ".prettierrc.json5",
    ".prettierrc.js",
    ".prettierrc.cjs",
    ".prettierrc.mjs",
    ".prettierrc.ts",
    ".prettierrc.toml",
    "prettier.config.js",
    "prettier.config.cjs",
    "prettier.config.mjs",
    "prettier.config.ts",
  },
  flag = "--config",
  fallback = vim.fn.stdpath("config") .. "/configs/prettierrc.yml",
}

--- @return tool-installer.Tool
function M.tool()
  return {
    bin = "prettier",
    mise = "npm:prettier",
    dependencies = { "node" },
  }
end

--- Build a conform.nvim spec that maps filetypes to prettier.
--- @param fts string|string[]
--- @return table lazy.nvim plugin spec
function M.conform(fts)
  if type(fts) == "string" then
    fts = { fts }
  end
  local by_ft = {}
  for _, ft in ipairs(fts) do
    by_ft[ft] = { "prettier" }
  end
  return {
    "stevearc/conform.nvim",
    opts = { formatters_by_ft = by_ft },
  }
end

-- ---------------------------------------------------------------------------
-- Resolve printWidth from prettier config (async, cached)
-- ---------------------------------------------------------------------------

--- Set textwidth on a buffer.
--- vim.bo doesn't fire OptionSet, so we also schedule a :setlocal to notify
--- listeners (e.g. virtcolumn.nvim) that need OptionSet to re-resolve
--- colorcolumn. The immediate vim.bo ensures textwidth takes effect without
--- waiting for the next event-loop tick.
--- @param buf integer
--- @param tw number
local function set_textwidth(buf, tw)
  vim.bo[buf].textwidth = tw
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].textwidth == tw then
      vim.api.nvim_buf_call(buf, function()
        vim.cmd("setlocal textwidth=" .. tw)
      end)
    end
  end)
end

-- Node script: resolve prettier's own module path from the binary, then call
-- resolveConfig(). Handles all 13+ config formats and per-file overrides.
local RESOLVE_SCRIPT = [[
const p=require('path'),f=require('fs');
const d=p.dirname(f.realpathSync(process.argv[1]));
require(p.resolve(d,'..')).resolveConfig(p.resolve(process.argv[2]))
  .then(c=>process.stdout.write(String((c&&c.printWidth)||'')));
]]

local DISK_CACHE_PATH = vim.fn.stdpath("cache") .. "/prettier-pw.json"

--- @class PrettierPwDiskEntry
--- @field pw number|false
--- @field mtime number config file mtime (seconds)

--- Session cache keyed by git root + ext.
--- Values: number (printWidth), false (no printWidth), or "pending" (in-flight).
--- @type table<string, number|false|"pending">
local _cache = {}
local _disk_dirty = false

--- Buffers waiting for an in-flight resolve to complete, keyed by cache key.
--- @type table<string, integer[]>
local _pending = {}

--- @type table<string, PrettierPwDiskEntry>?
local _disk_cache

local function load_disk_cache()
  if _disk_cache then
    return _disk_cache
  end
  local f = io.open(DISK_CACHE_PATH)
  if f then
    local ok, data = pcall(vim.json.decode, f:read("*a"))
    f:close()
    if ok and type(data) == "table" then
      _disk_cache = data
      return _disk_cache
    end
  end
  _disk_cache = {}
  return _disk_cache
end

local function flush_disk_cache()
  if not _disk_dirty or not _disk_cache then
    return
  end
  local f = io.open(DISK_CACHE_PATH, "w")
  if f then
    f:write(vim.json.encode(_disk_cache))
    f:close()
    _disk_dirty = false
  end
end

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = vim.api.nvim_create_augroup("PrettierCache", { clear = true }),
  callback = flush_disk_cache,
})

--- Find the prettier config file nearest to `path`, searching upward to `root`.
--- @param path string file path to search from
--- @param root string git root (stop directory)
--- @return string? config_path, number? mtime
local function find_config_file(path, root)
  -- vim.fs.find stop is exclusive — use parent so root itself is searched
  local stop = vim.fn.fnamemodify(root, ":h")
  local found = vim.fs.find(M.fallback_spec.names, {
    path = path,
    upward = true,
    stop = stop,
    type = "file",
    limit = 1,
  })
  if #found == 0 then
    return nil, nil
  end
  local stat = vim.uv.fs_stat(found[1])
  if not stat then
    return nil, nil
  end
  return found[1], stat.mtime.sec
end

--- Check whether `path` is inside a project that has a prettier config.
--- Extends has_project_config with a package.json "prettier" key check.
--- @param path string
--- @return boolean
local function has_prettier_config(path)
  if fallback_config.has_project_config(M.fallback_spec, path) then
    return true
  end
  -- Check package.json for "prettier" key
  local root = vim.fs.root(path, "package.json")
  if not root then
    return false
  end
  local pkg_path = root .. "/package.json"
  local stat = vim.uv.fs_stat(pkg_path)
  if not stat then
    return false
  end
  local fd = vim.uv.fs_open(pkg_path, "r", 438)
  if not fd then
    return false
  end
  local data = vim.uv.fs_read(fd, stat.size, 0)
  vim.uv.fs_close(fd)
  if not data then
    return false
  end
  local ok, pkg = pcall(vim.json.decode, data)
  return ok and pkg and pkg.prettier ~= nil
end

--- @return string? prettier binary path, re-checked each call (exepath is fast)
local function get_prettier_bin()
  local bin = vim.fn.exepath("prettier")
  return bin ~= "" and bin or nil
end

--- Apply printWidth to a buffer and any buffers waiting on the same key.
--- @param key string cache key
--- @param pw number|false|nil
local function apply_result(key, pw)
  local bufs = _pending[key] or {}
  _pending[key] = nil
  if not pw or pw <= 0 then
    return
  end
  for _, buf in ipairs(bufs) do
    if vim.api.nvim_buf_is_valid(buf) then
      set_textwidth(buf, pw)
    end
  end
end

--- Async resolve printWidth for a buffer and set textwidth.
--- No-op when prettier binary is missing or no config is found nearby.
--- @param bufnr integer
function M.resolve_print_width(bufnr)
  local file = vim.api.nvim_buf_get_name(bufnr)
  if file == "" then
    return
  end

  local root = vim.fs.root(file, ".git") or vim.fn.fnamemodify(file, ":h")
  local ext = vim.fn.fnamemodify(file, ":e")
  local key = root .. "::" .. ext

  -- L1: session memory cache (instant, no I/O)
  local cached = _cache[key]
  if cached == "pending" then
    table.insert(_pending[key], bufnr)
    return
  end
  if cached ~= nil then
    if cached and cached > 0 then
      set_textwidth(bufnr, cached)
    end
    return
  end

  -- L2: disk cache — valid if config file mtime unchanged
  local disk = load_disk_cache()
  local disk_entry = disk[key]
  if disk_entry then
    local _, mtime = find_config_file(file, root)
    if mtime and mtime == disk_entry.mtime then
      _cache[key] = disk_entry.pw
      if disk_entry.pw and disk_entry.pw > 0 then
        set_textwidth(bufnr, disk_entry.pw)
      end
      return
    end
  end

  -- Heavier checks before spawning Node
  if not has_prettier_config(file) then
    _cache[key] = false
    return
  end

  local prettier = get_prettier_bin()
  if not prettier then
    return
  end

  -- Mark in-flight to deduplicate concurrent resolves for the same key
  _cache[key] = "pending"
  _pending[key] = { bufnr }

  local _, config_mtime = find_config_file(file, root)

  vim.system(
    { "node", "-e", RESOLVE_SCRIPT, prettier, file },
    { text = true },
    function(result)
      -- Guard against signal kills and non-zero exits
      if result.code ~= 0 or (result.signal and result.signal ~= 0) then
        _cache[key] = false
        vim.schedule(function()
          apply_result(key, false)
        end)
        return
      end
      local pw = tonumber(result.stdout)
      -- Only cache negative result when stdout was actually empty (not garbage)
      if not pw and result.stdout and result.stdout:match("%S") then
        _cache[key] = false
        vim.schedule(function()
          apply_result(key, false)
        end)
        return
      end
      _cache[key] = pw or false
      if config_mtime then
        disk[key] = { pw = pw or false, mtime = config_mtime }
        _disk_dirty = true
      end
      vim.schedule(function()
        apply_result(key, pw)
      end)
    end
  )
end

return M
