-- Ensure config dir is on rtp (not always present with nvim -u)
vim.opt.rtp:prepend(vim.fn.stdpath("config"))

-- Options and keymaps first (leader must be set before lazy.nvim)
require("options")
require("keymaps")
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

require("lazy").setup({
  spec = {
    { import = "plugins" },
    { import = "plugins.themes" },
    { import = "langs" },
    vim.uv.fs_stat(vim.fn.stdpath("config") .. "/lua/local/plugins") and {
      import = "local.plugins",
    } or nil,
  },
  rocks = { enabled = false },
  lockfile = vim.env.NVIM_TEST and vim.fn.stdpath("cache") .. "/lazy-lock.json"
    or vim.fn.stdpath("config") .. "/lazy-lock.json",
})

-- Strip local plugin entries from lockfile after lazy.nvim operations
vim.api.nvim_create_autocmd("User", {
  pattern = { "LazyInstall", "LazyUpdate", "LazySync", "LazyRestore" },
  callback = function()
    require("lib.lockfile").strip_local_plugins()
  end,
})
