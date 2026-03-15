local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("sql", bufnr, {
    tools = {
      {
        bin = "postgres-language-server",
        mise = "npm:@postgres-language-server/cli",
        dependencies = { "node" },
      },
    },
    lsp = "postgres_lsp",
  })
end

return M
