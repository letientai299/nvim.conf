local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("sql", bufnr, {
    tools = {
      {
        bin = "postgres-language-server",
        kind = "lsp",
        mise = "npm:@postgres-language-server/cli",
      },
    },
    lsp = "postgres_lsp",
  })
end

return M
