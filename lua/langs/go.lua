local M = {}

function M.setup(bufnr)
  require("lib.tools").check_now({
    { name = "gopls", bin = "gopls", kind = "lsp" },
    { name = "goimports", bin = "goimports", kind = "fmt" },
    { name = "gofumpt", bin = "gofumpt", kind = "fmt" },
    { name = "golangci-lint", bin = "golangci-lint", kind = "lint" },
  })

  require("lib.lsp").enable("gopls", bufnr)

  local registry = require("lib.lang_registry")
  registry.add_formatters("go", { "goimports", "gofumpt" })
  registry.add_linter("go", { "golangcilint" })
  registry.ensure_parsers({ "go", "gomod", "gosum" })
end

return M
