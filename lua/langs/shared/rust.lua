local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("rust", bufnr, {
    tools = {
      { bin = "rust-analyzer", mise = "rust-analyzer" },
      { bin = "rustfmt" },
    },
    lsp = "rust_analyzer",
    formatters = { "rustfmt" },
  })
end

return M
