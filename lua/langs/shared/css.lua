local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("css", bufnr, {
    filetypes = { "css", "scss", "less" },
    tools = {
      {
        name = "vscode-css-language-server",
        bin = "vscode-css-language-server",
        kind = "lsp",
      },
      require("lib.prettier").tool(),
      { name = "biome", bin = "biome", kind = "lint" },
    },
    lsp = "cssls",
    formatter_fts = { "css", "scss", "less" },
    formatters = { "prettier" },
    linter_fts = "css",
    linters = { "biomejs" },
    parsers = { "css", "scss" },
  })
end

return M
