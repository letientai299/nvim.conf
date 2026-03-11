return {
  "neanias/everforest-nvim",
  lazy = true,
  themes = {
    { name = "Everforest Dark", colorscheme = "everforest", before = [[vim.opt.background = "dark"]] },
    { name = "Everforest Light", colorscheme = "everforest", before = [[vim.opt.background = "light"]] },
  },
}
