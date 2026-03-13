return {
  "craftzdog/solarized-osaka.nvim",
  lazy = true,
  main = "solarized-osaka",
  opts = function()
    return {
      dim_inactive = true,
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
        functions = { bold = true },
        sidebars = "dark",
        floats = "dark",
      },
    }
  end,
  themes = {
    "solarized-osaka",
    "solarized-osaka-day",
  },
}
