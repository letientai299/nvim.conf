return {
  "neanias/everforest-nvim",
  lazy = true,
  main = "everforest",
  opts = {
    italics = true,
    dim_inactive_windows = true,
  },
  themes = {
    {
      name = "Everforest Dark",
      colorscheme = "everforest",
      before = [[vim.opt.background = "dark"]],
    },
    {
      name = "Everforest Light",
      colorscheme = "everforest",
      before = [[vim.opt.background = "light"]],
    },
  },
}
