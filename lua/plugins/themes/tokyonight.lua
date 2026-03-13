return {
  "folke/tokyonight.nvim",
  lazy = true,
  opts = function()
    return {
      dim_inactive = true,
      lualine_bold = true,
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
        functions = { bold = true },
      },
    }
  end,
  themes = {
    "tokyonight-storm",
    "tokyonight-moon",
    "tokyonight-night",
    "tokyonight-day",
  },
}
