return {
  "ellisonleao/gruvbox.nvim",
  lazy = true,
  opts = function()
    return {
      dim_inactive = true,
      bold = true,
      italic = {
        strings = true,
        emphasis = true,
        comments = true,
        operators = false,
        folds = true,
      },
    }
  end,
  themes = {
    {
      name = "Gruvbox Dark",
      colorscheme = "gruvbox",
      before = [[vim.opt.background = "dark"]],
    },
    {
      name = "Gruvbox Light",
      colorscheme = "gruvbox",
      before = [[vim.opt.background = "light"]],
    },
  },
}
