-- Ensure config dir is on rtp (not always present with nvim -u)
vim.opt.rtp:prepend(vim.fn.stdpath("config"))

-- Options and keymaps first (leader must be set before lazy.nvim)
require("options")
require("keymaps")
require("commands")
require("notes").setup()
pcall(require, "local")

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

-- Read persisted colorscheme from themery state (avoid loading themery at startup)
local _themery_state = vim.fn.stdpath("data") .. "/themery/state.json"
local _themery_cs ---@type string?
do
  local f = io.open(_themery_state)
  if f then
    local ok, state = pcall(vim.json.decode, f:read("*a"))
    f:close()
    if ok and state then
      if state.globalBeforeCode and state.globalBeforeCode ~= "" then
        local fn = loadstring(state.globalBeforeCode)
        if fn then
          fn()
        end
      end
      if state.beforeCode and state.beforeCode ~= "" then
        local fn = loadstring(state.beforeCode)
        if fn then
          fn()
        end
      end
      _themery_cs = state.colorscheme
    end
  end
end

require("lazy").setup({
  spec = {
    { import = "plugins" },
    { import = "plugins.themes" },
    vim.uv.fs_stat(vim.fn.stdpath("config") .. "/lua/local/plugins") and {
      import = "local.plugins",
    } or nil,
  },
  install = { colorscheme = { _themery_cs or "default" } },
  change_detection = { enabled = false },
  rocks = { enabled = false },
  lockfile = vim.env.NVIM_TEST and vim.fn.stdpath("cache") .. "/lazy-lock.json"
    or vim.fn.stdpath("config") .. "/lazy-lock.json",
})

-- Apply persisted colorscheme (lazy.nvim auto-loads the theme plugin)
if _themery_cs then
  pcall(vim.cmd.colorscheme, _themery_cs)
end

-- Strip local plugin entries from lockfile after lazy.nvim operations
vim.api.nvim_create_autocmd("User", {
  pattern = { "LazyInstall", "LazyUpdate", "LazySync", "LazyRestore" },
  callback = function()
    require("lib.lockfile").strip_local_plugins()
  end,
})
