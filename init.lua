vim.loader.enable()

-- Cache stdpath results (each call crosses the Lua→Vimscript bridge)
local _dir_config = vim.fn.stdpath("config") --[[@as string]]
local _dir_data = vim.fn.stdpath("data") --[[@as string]]
local _dir_state = vim.fn.stdpath("state") --[[@as string]]
local _dir_cache = vim.fn.stdpath("cache") --[[@as string]]

-- Ensure config dir is on rtp (not always present with nvim -u)
vim.opt.rtp:prepend(_dir_config)

-- Options and keymaps first (leader must be set before lazy.nvim)
require("options")
require("keymaps")
require("commands")
-- notes: lazy-load on command/keymap (avoids require at startup)
vim.api.nvim_create_user_command("NoteToday", function()
  require("notes").note_today()
end, { desc = "Open/append to today's diary note" })
vim.keymap.set("n", "<Leader>td", function()
  require("notes").note_today()
end, { desc = "Open today's diary note" })
if vim.uv.fs_stat(_dir_config .. "/lua/local/init.lua") then
  require("local")
end

-- Disable netrw (oil.nvim replaces it)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Bootstrap lazy.nvim
local lazypath = _dir_data .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Cache Themery's JSON state as a tiny Lua chunk so the hot startup path avoids
-- JSON decode and repeated loadstring work.
local _themery_state = _dir_data .. "/themery/state.json"
local _themery_cache = _dir_state .. "/themery-startup.lua"
local _theme_hl_cache = _dir_state .. "/theme-highlight-startup.lua"
local _theme_spec_cache = _dir_state .. "/theme-spec_gen.lua"
local _lazy_lockfile = vim.env.NVIM_TEST and _dir_cache .. "/lazy-lock.json"
  or _dir_config .. "/lazy-lock.json"

local function _mtime(path)
  local stat = vim.uv.fs_stat(path)
  if not stat or not stat.mtime then
    return nil
  end
  return stat.mtime.sec * 1000000000 + stat.mtime.nsec
end

local function _themery_load_cached()
  local ok, cached = pcall(dofile, _themery_cache)
  if not ok then
    return nil
  end

  if type(cached) == "string" and cached ~= "" then
    return {
      colorscheme = cached,
      before = "",
      after = "",
      plugin = nil,
      _legacy = true,
    }
  end

  if type(cached) == "table" and type(cached.colorscheme) == "string" then
    return {
      colorscheme = cached.colorscheme,
      before = type(cached.before) == "string" and cached.before or "",
      after = type(cached.after) == "string" and cached.after or "",
      plugin = type(cached.plugin) == "string"
          and cached.plugin ~= ""
          and cached.plugin
        or nil,
    }
  end
end

local function _themery_decode_state()
  local f = io.open(_themery_state)
  if not f then
    return nil
  end
  local ok, state = pcall(vim.json.decode, f:read("*a"))
  f:close()
  if not ok or type(state) ~= "table" then
    return nil
  end
  return state
end

local function _themery_find_plugin(colorscheme)
  local ok, catalog = pcall(require, "plugins.themes.catalog")
  if not ok then
    return nil
  end

  for _, spec in ipairs(catalog.load_specs()) do
    for _, theme in ipairs(spec.themes or {}) do
      local name = type(theme) == "string" and theme or theme.colorscheme
      if name == colorscheme then
        local plugin = spec.name
        if type(plugin) == "string" and plugin ~= "" then
          return plugin
        end
        local source = spec[1]
        if type(source) == "string" and source ~= "" then
          return source:match("/([^/]+)$") or source
        end
        return nil
      end
    end
  end
end

local function _themery_write_cache(state)
  local colorscheme = state.colorscheme
  if type(colorscheme) ~= "string" then
    return
  end

  local before = {}
  local after = {}

  for _, key in ipairs({ "globalBeforeCode", "beforeCode" }) do
    local code = state[key]
    if type(code) == "string" and code ~= "" then
      before[#before + 1] = code
    end
  end

  for _, key in ipairs({ "afterCode", "globalAfterCode" }) do
    local code = state[key]
    if type(code) == "string" and code ~= "" then
      after[#after + 1] = code
    end
  end

  local lines = {
    "-- Auto-generated from Themery state.",
    "return {",
    string.format("  colorscheme = %q,", colorscheme),
    string.format("  before = %q,", table.concat(before)),
    string.format("  after = %q,", table.concat(after)),
    string.format("  plugin = %q,", _themery_find_plugin(colorscheme) or ""),
    "}",
  }

  local f = io.open(_themery_cache, "w")
  if not f then
    return
  end
  f:write(table.concat(lines, "\n"))
  f:write("\n")
  f:close()
end

local function _themery_cache_stale()
  local state_mtime = _mtime(_themery_state)
  if not state_mtime then
    return false
  end
  local cache_mtime = _mtime(_themery_cache)
  if not cache_mtime then
    return true
  end
  return state_mtime > cache_mtime
end

local function _themery_exec(code, label)
  if type(code) ~= "string" or code == "" then
    return true
  end

  local chunk, err = load(code, "=" .. label)
  if not chunk then
    vim.notify("Themery " .. label .. " failed: " .. err, vim.log.levels.ERROR)
    return false
  end

  local ok, exec_err = pcall(chunk)
  if not ok then
    vim.notify(
      "Themery " .. label .. " failed: " .. exec_err,
      vim.log.levels.ERROR
    )
    return false
  end

  return true
end

local function _themery_load()
  if not _themery_cache_stale() then
    local cached = _themery_load_cached()
    if
      cached
      and not cached._legacy
      and (cached.plugin or cached.colorscheme == "default")
    then
      return cached
    end
  end

  local state = _themery_decode_state()
  if state then
    _themery_write_cache(state)
  end

  return _themery_load_cached()
end

local function _theme_hl_cache_stale()
  local cache_mtime = _mtime(_theme_hl_cache)
  if not cache_mtime then
    return true
  end

  for _, path in ipairs({ _themery_cache, _theme_spec_cache, _lazy_lockfile }) do
    local current = _mtime(path)
    if current and current > cache_mtime then
      return true
    end
  end

  return false
end

local function _theme_write_hl_cache(colorscheme)
  local groups = vim.fn.getcompletion("", "highlight")
  table.sort(groups)

  local lines = {
    "-- Auto-generated startup highlight cache.",
    "local set_hl = vim.api.nvim_set_hl",
    string.format("vim.g.colors_name = %q", colorscheme),
  }

  for i = 0, 15 do
    local key = "terminal_color_" .. i
    local value = vim.g[key]
    if type(value) == "string" and value ~= "" then
      lines[#lines + 1] = string.format("vim.g[%q] = %q", key, value)
    end
  end

  for _, name in ipairs(groups) do
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = true })
    if ok and type(hl) == "table" then
      lines[#lines + 1] =
        string.format("set_hl(0, %q, %s)", name, vim.inspect(hl))
    end
  end

  local f = io.open(_theme_hl_cache, "w")
  if not f then
    return
  end
  f:write(table.concat(lines, "\n"))
  f:write("\n")
  f:close()
end

local _theme_cache_meta
local _theme_cache_scheduled = false

local function _theme_request_hl_cache(meta)
  if
    not meta
    or type(meta.colorscheme) ~= "string"
    or meta.colorscheme == ""
  then
    return
  end

  _theme_cache_meta = meta
  if _theme_cache_scheduled then
    return
  end
  _theme_cache_scheduled = true

  local function write()
    _theme_cache_scheduled = false
    local current = _theme_cache_meta
    if not current or vim.g.colors_name ~= current.colorscheme then
      return
    end
    if not _theme_hl_cache_stale() then
      return
    end
    _theme_write_hl_cache(current.colorscheme)
  end

  -- Headless benchmarks never reach a real first redraw, so write the cache
  -- immediately there. Interactive boots defer it until after startup settles.
  if #vim.api.nvim_list_uis() == 0 then
    write()
  elseif vim.v.vim_did_enter == 0 then
    vim.api.nvim_create_autocmd("User", {
      pattern = "VeryLazy",
      once = true,
      callback = write,
    })
  else
    vim.schedule(write)
  end
end

local function _theme_apply_cached(meta)
  if
    not meta
    or type(meta.colorscheme) ~= "string"
    or meta.colorscheme == ""
    or _theme_hl_cache_stale()
  then
    return false
  end

  local ok, err = pcall(function()
    local loader = require("lazy.core.loader")
    if meta.plugin then
      loader.load(meta.plugin, { colorscheme = meta.colorscheme })
    else
      loader.colorscheme(meta.colorscheme)
    end
    dofile(_theme_hl_cache)
    vim.api.nvim_exec_autocmds("ColorScheme", {
      pattern = meta.colorscheme,
      modeline = false,
    })
  end)

  if not ok then
    vim.notify("Theme startup cache failed: " .. err, vim.log.levels.ERROR)
    return false
  end

  return true
end

local _themery = _themery_load()

require("lazy").setup({
  spec = {
    {
      name = "plugins",
      import = function()
        return require("plugins.catalog").load_specs()
      end,
    },
    {
      name = "plugins.themes",
      import = function()
        return require("plugins.themes")
      end,
    },
    vim.uv.fs_stat(_dir_config .. "/lua/local/plugins") and {
      import = "local.plugins",
    } or nil,
  },
  install = {
    missing = false,
    colorscheme = { (_themery and _themery.colorscheme) or "default" },
  },
  change_detection = { enabled = false },
  local_spec = false,
  pkg = { enabled = false },
  rocks = { enabled = false },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "man",
        "matchit",
        "matchparen",
        "osc52",
        "rplugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
  lockfile = _lazy_lockfile,
})

-- Auto-clone missing plugins when their lazy-load trigger fires
require("lib.lazy_ondemand").enable()

-- Apply persisted colorscheme (lazy.nvim auto-loads the theme plugin)
if _themery and _themery.colorscheme then
  _themery_exec(_themery.before, "beforeCode")

  local theme_from_cache = _theme_apply_cached(_themery)
  local theme_loaded = theme_from_cache
  if not theme_loaded then
    local ok, err = pcall(vim.cmd.colorscheme, _themery.colorscheme)
    if ok then
      theme_loaded = true
    else
      vim.notify("Failed to load colorscheme: " .. err, vim.log.levels.ERROR)
    end
  end

  if theme_loaded then
    _themery_exec(_themery.after, "afterCode")
    if not theme_from_cache then
      _theme_request_hl_cache(_themery)
    end
  end
end

-- Match split and column borders to floating window border color
local function _sync_border_highlights()
  local fb = vim.api.nvim_get_hl(0, { name = "FloatBorder", link = false })
  local fg = fb.fg
  if not fg then
    return
  end
  vim.api.nvim_set_hl(0, "WinSeparator", { fg = fg })
end
_sync_border_highlights()

-- Strip local plugin entries from lockfile after lazy.nvim operations
vim.api.nvim_create_autocmd("User", {
  pattern = { "LazyInstall", "LazyUpdate", "LazySync", "LazyRestore" },
  callback = function()
    require("lib.lockfile").strip_local_plugins()
  end,
})
