return {
  "Mofiqul/vscode.nvim",
  lazy = true,
  opts = function()
    return {
      italic_comments = true,
    }
  end,
  themes = {
    {
      name = "VSCode Dark",
      colorscheme = "vscode",
      before = [[vim.opt.background = "dark"]],
    },
    {
      name = "VSCode Light",
      colorscheme = "vscode",
      before = [[vim.opt.background = "light"]],
    },
  },
}
