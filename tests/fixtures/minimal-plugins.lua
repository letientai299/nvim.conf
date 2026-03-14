-- Minimal plugin spec for testing lazy_ondemand auto-clone.
-- Uses 2 small plugins with different triggers to verify selective cloning.

local config_dir = vim.fn.stdpath("config") --[[@as string]]
vim.opt.rtp:prepend(config_dir)

local data_dir = vim.fn.stdpath("data") --[[@as string]]
local lazypath = data_dir .. "/lazy/lazy.nvim"
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

local cache_dir = vim.fn.stdpath("cache") --[[@as string]]

require("lazy").setup({
  spec = {
    -- Loads on BufReadPre — should clone when opening a file
    {
      "nvim-lua/plenary.nvim",
      event = { "BufReadPre", "BufNewFile" },
    },
    -- Loads on command only — should NOT clone when just opening a file
    {
      "xiyaowong/virtcolumn.nvim",
      cmd = "VirtcolumnToggle",
    },
  },
  install = { missing = false },
  change_detection = { enabled = false },
  local_spec = false,
  pkg = { enabled = false },
  rocks = { enabled = false },
  lockfile = cache_dir .. "/lazy-lock-test.json",
})

require("lib.lazy_ondemand").enable()
