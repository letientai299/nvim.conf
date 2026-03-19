return {
  "jmbuhr/otter.nvim",
  ft = { "markdown", "markdown.mdx" },
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  opts = {
    lsp = {
      diagnostic_update_events = { "BufWritePost", "InsertLeave" },
    },
    verbose = { no_code_found = false },
  },
}
