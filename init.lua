vim.loader.enable()

-- Ensure config dir is on rtp (not always present with nvim -u)
vim.opt.rtp:prepend(vim.fn.stdpath("config"))

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
if vim.uv.fs_stat(vim.fn.stdpath("config") .. "/lua/local/init.lua") then
  require("local")
end

-- Disable netrw (oil.nvim replaces it)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
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
local _themery_state = vim.fn.stdpath("data") .. "/themery/state.json"
local _themery_cache = vim.fn.stdpath("state") .. "/themery-startup.lua"

local function _themery_mtime(path)
  local stat = vim.uv.fs_stat(path)
  if not stat or not stat.mtime then
    return nil
  end
  return stat.mtime.sec * 1000000000 + stat.mtime.nsec
end

local function _themery_load_cached()
  local ok, colorscheme = pcall(dofile, _themery_cache)
  if ok and type(colorscheme) == "string" and colorscheme ~= "" then
    return colorscheme
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

local function _themery_write_cache(state)
  local colorscheme = state.colorscheme
  if type(colorscheme) ~= "string" then
    return
  end

  local lines = { "-- Auto-generated from Themery state." }
  for _, key in ipairs({ "globalBeforeCode", "beforeCode" }) do
    local code = state[key]
    if type(code) == "string" and code ~= "" then
      lines[#lines + 1] = code
    end
  end
  lines[#lines + 1] = string.format("return %q", colorscheme)

  local f = io.open(_themery_cache, "w")
  if not f then
    return
  end
  f:write(table.concat(lines, "\n"))
  f:write("\n")
  f:close()
end

local function _themery_cache_stale()
  local state_mtime = _themery_mtime(_themery_state)
  if not state_mtime then
    return false
  end
  local cache_mtime = _themery_mtime(_themery_cache)
  if not cache_mtime then
    return true
  end
  return state_mtime > cache_mtime
end

local function _themery_load()
  if not _themery_cache_stale() then
    local colorscheme = _themery_load_cached()
    if colorscheme then
      return colorscheme
    end
  end

  local state = _themery_decode_state()
  if state then
    _themery_write_cache(state)
  end

  return _themery_load_cached()
end

local _themery_cs = _themery_load()

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
    vim.uv.fs_stat(vim.fn.stdpath("config") .. "/lua/local/plugins") and {
      import = "local.plugins",
    } or nil,
  },
  install = { colorscheme = { _themery_cs or "default" } },
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
  lockfile = vim.env.NVIM_TEST and vim.fn.stdpath("cache") .. "/lazy-lock.json"
    or vim.fn.stdpath("config") .. "/lazy-lock.json",
})

-- Apply persisted colorscheme (lazy.nvim auto-loads the theme plugin)
if _themery_cs then
  pcall(vim.cmd.colorscheme, _themery_cs)
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
