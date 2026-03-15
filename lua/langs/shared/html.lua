local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("html", bufnr, {
    tools = {
      {
        bin = "vscode-html-language-server",
        mise = "npm:vscode-langservers-extracted",
        dependencies = { "node" },
      },
      require("lib.prettier").tool(),
    },
    lsp = "html",
    formatters = { "prettier" },
  })
end

return M
