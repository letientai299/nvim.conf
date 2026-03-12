local M = {}

local fts = { "javascript", "javascriptreact", "typescript", "typescriptreact" }

function M.setup(bufnr)
  require("langs.shared.entry").setup("js_ts", bufnr, {
    tools = {
      { name = "vtsls", bin = "vtsls", kind = "lsp" },
      require("lib.prettier").tool(),
      { name = "biome", bin = "biome", kind = "lint" },
      {
        name = "cssmodules-language-server",
        bin = "cssmodules-language-server",
        kind = "lsp",
      },
    },
    lsps = { "vtsls", "cssmodules_ls" },
    formatter_fts = fts,
    formatters = { "prettier" },
    linter_fts = fts,
    linters = { "biomejs" },
    parsers = { "javascript", "typescript", "tsx", "jsdoc" },
  })
end

return M
