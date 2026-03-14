local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("json", bufnr, {
    tools = {
      {
        name = "vscode-json-languageserver",
        bin = "vscode-json-languageserver",
        kind = "lsp",
      },
      require("lib.prettier").tool(),
    },
    lsp = "jsonls",
    formatter_fts = { "json", "jsonc" },
    formatters = { "prettier" },
  })
end

return M
