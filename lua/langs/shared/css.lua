local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("css", bufnr, {
    filetypes = { "css", "scss", "less" },
    tools = {
      {
        bin = "vscode-css-language-server",
        kind = "lsp",
        mise = "npm:vscode-langservers-extracted",
      },
      require("lib.prettier").tool(),
      require("lib.biome").tool(),
    },
    lsp = "cssls",
    formatter_fts = { "css", "scss", "less" },
    formatters = { "prettier" },
    linter_fts = "css",
    linters = { "biomejs" },
  })
end

return M
