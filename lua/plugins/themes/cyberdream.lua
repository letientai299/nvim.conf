return {
  "scottmckendry/cyberdream.nvim",
  lazy = true,
  opts = function()
    return {
      italic_comments = true,
      hide_fillchars = true,
      terminal_colors = true,
      cache = true,
      extensions = {
        alpha = true,
        blinkcmp = true,
        gitsigns = true,
        mini = true,
        telescope = true,
        treesitter = true,
      },
    }
  end,
  themes = {
    "cyberdream",
  },
}
