local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("html", bufnr, {
    tools = {
      {
        bin = "vscode-html-language-server",
        kind = "lsp",
        mise = "npm:vscode-langservers-extracted",
      },
      require("lib.prettier").tool(),
    },
    lsp = "html",
    formatters = { "prettier" },
  })
end

return M
