-- Test runner bootstrap: loads mini.test, NOT the user config.
-- Child Neovim processes load the real config via -u init.lua.

vim.opt.rtp:append(".tests/deps/mini.nvim")
require("mini.test").setup()
