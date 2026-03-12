return {
  "yorik1984/newpaper.nvim",
  lazy = true,
  opts = {
    italic_comments = true,
    italic_functions = true,
    keywords = "italic",
  },
  themes = {
    {
      name = "Newpaper Light",
      colorscheme = "newpaper",
      before = [[vim.opt.background = "light"]],
    },
    {
      name = "Newpaper Dark",
      colorscheme = "newpaper",
      before = [[vim.opt.background = "dark"]],
    },
  },
}
