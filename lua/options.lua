-- Editor options ported from vimrc / common.vim

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.backupcopy = "yes"
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.colorcolumn = "0"
vim.opt.wrap = false
vim.opt.undofile = true
vim.opt.signcolumn = "yes:1"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.foldenable = false
vim.opt.foldlevel = 99
vim.opt.spelllang = "en_us"
vim.opt.timeoutlen = 300
-- vim.opt.winblend = 40
vim.opt.concealcursor = "nc"
vim.opt.fillchars:append({ eob = " " })
vim.opt.formatoptions:append("r")

vim.api.nvim_create_user_command("GitRoot", function()
  local root = vim.fs.root(0, ".git")
  if root then
    vim.fn.chdir(root)
    vim.notify(root)
  else
    vim.notify("Not in a git repo", vim.log.levels.WARN)
  end
end, {})
