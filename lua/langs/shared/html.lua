local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("html", bufnr, {
    tools = {
      {
        name = "vscode-html-language-server",
        bin = "vscode-html-language-server",
        kind = "lsp",
      },
      require("lib.prettier").tool(),
    },
    lsp = "html",
    formatters = { "prettier" },
  })
end

return M
