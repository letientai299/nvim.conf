return {
  "rebelot/kanagawa.nvim",
  lazy = true,
  opts = function()
    return {
      compile = true,
      dimInactive = true,
      commentStyle = { italic = true },
      keywordStyle = { italic = true },
      statementStyle = { bold = true },
      typeStyle = { bold = true },
    }
  end,
  themes = {
    "kanagawa-wave",
    "kanagawa-dragon",
    "kanagawa-lotus",
  },
}
