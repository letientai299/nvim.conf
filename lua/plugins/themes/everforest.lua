return {
  "neanias/everforest-nvim",
  lazy = true,
  main = "everforest",
  opts = function()
    return {
      italics = true,
      dim_inactive_windows = true,
    }
  end,
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
