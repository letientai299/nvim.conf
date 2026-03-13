return {
  "olimorris/onedarkpro.nvim",
  lazy = true,
  opts = function()
    return {
      options = {
        highlight_inactive_windows = true,
      },
      styles = {
        comments = "italic",
        keywords = "italic",
        functions = "bold",
        types = "bold",
      },
    }
  end,
  themes = {
    "onedark",
    "onedark_vivid",
    "onedark_dark",
    "onelight",
  },
}
