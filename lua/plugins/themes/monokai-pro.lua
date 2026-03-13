return {
  "loctvl842/monokai-pro.nvim",
  lazy = true,
  opts = function()
    return {
      styles = {
        comment = { italic = true },
        keyword = { italic = true },
        type = { italic = true },
      },
    }
  end,
  themes = {
    "monokai-pro",
    "monokai-pro-classic",
    "monokai-pro-machine",
    "monokai-pro-octagon",
    "monokai-pro-ristretto",
    "monokai-pro-spectrum",
  },
}
