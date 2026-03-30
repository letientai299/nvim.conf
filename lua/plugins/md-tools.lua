return {
  dir = vim.fn.stdpath("config") .. "/plugins/md-tools",
  ft = { "markdown", "mdx" },
  config = function()
    require("md-tools").setup()
  end,
}
