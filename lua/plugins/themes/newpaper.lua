return {
  "yorik1984/newpaper.nvim",
  lazy = true,
  themes = {
    { name = "Newpaper Light", colorscheme = "newpaper", before = [[vim.opt.background = "light"]] },
    { name = "Newpaper Dark", colorscheme = "newpaper", before = [[vim.opt.background = "dark"]] },
  },
}
