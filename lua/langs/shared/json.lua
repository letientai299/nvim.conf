local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("json", bufnr, {
    tools = {
      {
        bin = "vscode-json-languageserver",
        kind = "lsp",
        mise = "npm:vscode-json-languageserver",
      },
      require("lib.prettier").tool(),
    },
    lsp = "jsonls",
    formatter_fts = { "json", "jsonc" },
    formatters = { "prettier" },
  })
end

return M
