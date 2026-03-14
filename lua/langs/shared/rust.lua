local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("rust", bufnr, {
    tools = {
      { bin = "rust-analyzer", kind = "lsp", mise = "rust-analyzer" },
      { bin = "rustfmt", kind = "fmt" },
    },
    lsp = "rust_analyzer",
    formatters = { "rustfmt" },
  })
end

return M
