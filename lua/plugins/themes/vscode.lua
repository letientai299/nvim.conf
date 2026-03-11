return {
  "Mofiqul/vscode.nvim",
  lazy = true,
  opts = {
    italic_comments = true,
  },
  themes = {
    { name = "VSCode Dark", colorscheme = "vscode", before = [[vim.opt.background = "dark"]] },
    { name = "VSCode Light", colorscheme = "vscode", before = [[vim.opt.background = "light"]] },
  },
}
