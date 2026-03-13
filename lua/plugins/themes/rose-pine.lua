return {
  "rose-pine/neovim",
  name = "rose-pine",
  lazy = true,
  main = "rose-pine",
  opts = function()
    return {
      dim_inactive_windows = true,
      styles = {
        italic = true,
        bold = true,
      },
    }
  end,
  themes = {
    "rose-pine-main",
    "rose-pine-moon",
    "rose-pine-dawn",
  },
}
