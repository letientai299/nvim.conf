return {
  "nyoom-engineering/oxocarbon.nvim",
  lazy = true,
  themes = {
    {
      name = "Oxocarbon Dark",
      colorscheme = "oxocarbon",
      before = [[vim.opt.background = "dark"]],
    },
    {
      name = "Oxocarbon Light",
      colorscheme = "oxocarbon",
      before = [[vim.opt.background = "light"]],
    },
  },
}
