return {
  "yorik1984/newpaper.nvim",
  lazy = true,
  opts = function()
    return {
      italic_comments = true,
      italic_functions = true,
      keywords = "italic",
    }
  end,
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
