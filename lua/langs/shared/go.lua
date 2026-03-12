local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("go", bufnr, {
    tools = {
      { name = "gopls", bin = "gopls", kind = "lsp" },
      { name = "goimports", bin = "goimports", kind = "fmt" },
      { name = "gofumpt", bin = "gofumpt", kind = "fmt" },
      { name = "golangci-lint", bin = "golangci-lint", kind = "lint" },
    },
    lsp = "gopls",
    formatter_fts = "go",
    formatters = { "goimports", "gofumpt" },
    linter_fts = "go",
    linters = { "golangcilint" },
    parsers = { "go", "gomod", "gosum" },
  })
end

return M
