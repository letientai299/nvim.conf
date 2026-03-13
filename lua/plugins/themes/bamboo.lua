return {
  "ribru17/bamboo.nvim",
  lazy = true,
  opts = function()
    return {
      dim_inactive = true,
      code_style = {
        comments = { italic = true },
        conditionals = { italic = true },
        keywords = { italic = true },
        namespaces = { italic = true },
        parameters = { italic = true },
        functions = { bold = true },
      },
    }
  end,
  themes = {
    "bamboo",
    "bamboo-light",
    "bamboo-multiplex",
  },
}
