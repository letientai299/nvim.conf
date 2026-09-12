return {
  dir = vim.fn.stdpath("config") .. "/plugins/md-tools",
  ft = { "markdown", "mdx", "quarto" },
  config = function()
    require("md-tools").setup()
  end,
}
