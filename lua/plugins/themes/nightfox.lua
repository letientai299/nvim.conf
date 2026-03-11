return {
  "EdenEast/nightfox.nvim",
  lazy = true,
  opts = {
    options = {
      dim_inactive = true,
      styles = {
        comments = "italic",
        keywords = "italic",
        conditionals = "italic",
        functions = "bold",
        types = "bold",
      },
      modules = {
        alpha = true,
        mini = true,
        native_lsp = { enable = true },
        treesitter = true,
      },
    },
  },
  themes = {
    "nightfox",
    "dayfox",
    "dawnfox",
    "duskfox",
    "nordfox",
    "terafox",
    "carbonfox",
  },
}
