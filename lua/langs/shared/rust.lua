local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("rust", bufnr, {
    tools = {
      { name = "rust-analyzer", bin = "rust-analyzer", kind = "lsp" },
      { name = "rustfmt", bin = "rustfmt", kind = "fmt" },
    },
    lsp = "rust_analyzer",
    formatters = { "rustfmt" },
  })
end

return M
