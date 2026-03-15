local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("go", bufnr, {
    tools = {
      {
        bin = "gopls",
        mise = "go:golang.org/x/tools/gopls",
        dependencies = { "go" },
      },
      {
        bin = "goimports",
        mise = "go:golang.org/x/tools/cmd/goimports",
        dependencies = { "go" },
      },
      {
        bin = "gofumpt",
        mise = "go:mvdan.cc/gofumpt",
        dependencies = { "go" },
      },
      {
        bin = "golangci-lint",
        mise = "go:github.com/golangci/golangci-lint/cmd/golangci-lint",
        dependencies = { "go" },
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
