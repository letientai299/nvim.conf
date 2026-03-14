local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("sql", bufnr, {
    tools = {
      {
        name = "postgres-language-server",
        bin = "postgres-language-server",
        kind = "lsp",
      },
      { name = "pgFormatter", bin = "pg_format", kind = "fmt" },
    },
    lsp = "postgres_lsp",
    formatters = { "pg_format" },
  })
end

return M
