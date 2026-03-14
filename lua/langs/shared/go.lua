local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("go", bufnr, {
    tools = {
      { bin = "gopls", kind = "lsp", mise = "go:golang.org/x/tools/gopls" },
      {
        bin = "goimports",
        kind = "fmt",
        mise = "go:golang.org/x/tools/cmd/goimports",
      },
      { bin = "gofumpt", kind = "fmt", mise = "go:mvdan.cc/gofumpt" },
      {
        bin = "golangci-lint",
        kind = "lint",
        mise = "go:github.com/golangci/golangci-lint/cmd/golangci-lint",
      },
    },
    lsp = "gopls",
    formatter_fts = "go",
    formatters = { "goimports", "gofumpt" },
    linter_fts = "go",
    linters = { "golangcilint" },
  })
end

return M
