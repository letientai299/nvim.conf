return {
  "folke/tokyonight.nvim",
  lazy = true,
  opts = {
    dim_inactive = true,
    lualine_bold = true,
    styles = {
      comments = { italic = true },
      keywords = { italic = true },
      functions = { bold = true },
    },
  },
  themes = {
    "tokyonight-storm",
    "tokyonight-moon",
    "tokyonight-night",
    "tokyonight-day",
  },
}
