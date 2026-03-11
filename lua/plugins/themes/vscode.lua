return {
  "Mofiqul/vscode.nvim",
  lazy = true,
  themes = {
    { name = "VSCode Dark", colorscheme = "vscode", before = [[vim.opt.background = "dark"]] },
    { name = "VSCode Light", colorscheme = "vscode", before = [[vim.opt.background = "light"]] },
  },
}
