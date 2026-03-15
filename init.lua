vim.loader.enable()

-- Defer ShaDa reading — marks, registers, command history aren't needed for
-- first paint. Restore after VeryLazy. Skip deferral for bare `nvim` so
-- alpha.nvim can read v:oldfiles immediately.
local _defer_shada = vim.fn.argc(-1) > 0
if _defer_shada then
  vim.o.shadafile = "NONE"
end

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

-- Lockfile path — writable location for lazy.nvim to record plugin versions.
--
-- tests/run.sh mounts the repo read-only into a container so host edits are
-- visible without restart. lazy.nvim needs to write lazy-lock.json after
-- plugin installs, which fails on a read-only mount. We probe writability at
-- startup and redirect to ~/.cache/nvim/ when the config dir is read-only.
-- NVIM_TEST also forces the redirect (used by CI / test harnesses).
local _lazy_lockfile = (function()
  if vim.env.NVIM_TEST then
    return _dir_cache .. "/lazy-lock.json"
  end
  if vim.uv.fs_access(_dir_config, "W") then
    return _dir_config .. "/lazy-lock.json"
  end
  return _dir_cache .. "/lazy-lock.json"
end)()

-- Load persisted theme state (single Lua file, no JSON decode or staleness check).
-- store-theme plugin owns writing this file and the highlight cache.
local _theme_state_path = _dir_state .. "/store/theme.lua"
local _theme_hl_cache = _dir_state .. "/theme-highlight-startup.lua"

local _theme_state
do
  local ok, state = pcall(dofile, _theme_state_path)
  if ok and type(state) == "table" and type(state.colorscheme) == "string" then
    _theme_state = state
  end
end

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
    colorscheme = { (_theme_state and _theme_state.colorscheme) or "default" },
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
        "netrwPlugin",
        "osc52",
        "rplugin",
        "spellfile",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
  lockfile = _lazy_lockfile,
})

-- Auto-clone missing plugins when their lazy-load trigger fires (deferred —
-- enable() pulls in several lazy.manage submodules not needed for first paint)
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  once = true,
  callback = function()
    require("lib.lazy_ondemand").enable()
  end,
})

-- Apply persisted colorscheme, or fall back to catppuccin-mocha on first run.
-- The hl cache file is valid-or-absent — store-theme owns invalidation.
do
  local state = _theme_state
  local cs = (state and state.colorscheme) or "catppuccin-mocha"

  -- Run before hook (e.g., vim.opt.background = "dark" for gruvbox)
  if state and state.before and state.before ~= "" then
    require("store-theme.hook").exec(state.before, "theme.before")
  end

  -- Fast path: replay cached highlight groups (sub-5ms)
  local from_cache = false
  if state and vim.uv.fs_stat(_theme_hl_cache) then
    local ok, err = pcall(function()
      local loader = require("lazy.core.loader")
      if state.plugin then
        loader.load(state.plugin, { colorscheme = cs })
      else
        loader.colorscheme(cs)
      end
      dofile(_theme_hl_cache)
      vim.api.nvim_exec_autocmds("ColorScheme", {
        pattern = cs,
        modeline = false,
      })
    end)
    from_cache = ok
    if not ok then
      vim.notify("Theme cache failed: " .. err, vim.log.levels.WARN)
    end
  end

  -- Slow path: normal colorscheme load
  if not from_cache then
    local ok, err = pcall(vim.cmd.colorscheme, cs)
    if not ok and cs ~= "default" then
      pcall(vim.cmd.colorscheme, "default")
    elseif not ok then
      vim.notify("Failed to load colorscheme: " .. err, vim.log.levels.ERROR)
    end
  end

  -- Run after hook
  if state and state.after and state.after ~= "" then
    require("store-theme.hook").exec(state.after, "theme.after")
  end

  -- Schedule hl cache generation on first boot or when cache was stale
  if not from_cache and cs ~= "default" then
    require("store-theme.cache").schedule_write(cs)
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

-- Restore ShaDa after startup settles
if _defer_shada then
  vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    once = true,
    callback = function()
      vim.o.shadafile = ""
      pcall(vim.cmd.rshada, { bang = true })
    end,
  })
end
