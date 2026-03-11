return {
  "ellisonleao/gruvbox.nvim",
  lazy = true,
  themes = {
    { name = "Gruvbox Dark", colorscheme = "gruvbox", before = [[vim.opt.background = "dark"]] },
    { name = "Gruvbox Light", colorscheme = "gruvbox", before = [[vim.opt.background = "light"]] },
  },
}
