local M = {}

function M.setup(bufnr)
  require("lib.tools").check_now({
    { name = "postgres-language-server", bin = "postgres-language-server", kind = "lsp" },
    { name = "pgFormatter", bin = "pg_format", kind = "fmt" },
  })

  require("lib.lsp").enable("postgres_lsp", bufnr)

  local registry = require("lib.lang_registry")
  registry.add_formatters("sql", { "pg_format" })
  registry.ensure_parsers({ "sql" })
end

return M
