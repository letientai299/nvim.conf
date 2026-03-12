return {
  "savq/melange-nvim",
  lazy = true,
  themes = {
    {
      name = "Melange Dark",
      colorscheme = "melange",
      before = [[vim.opt.background = "dark"]],
    },
    {
      name = "Melange Light",
      colorscheme = "melange",
      before = [[vim.opt.background = "light"]],
    },
  },
}
