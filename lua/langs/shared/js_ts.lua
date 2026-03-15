local M = {}

local fts = { "javascript", "javascriptreact", "typescript", "typescriptreact" }

function M.setup(bufnr)
  require("langs.shared.entry").setup("js_ts", bufnr, {
    tools = {
      {
        bin = "vtsls",
        mise = "npm:@vtsls/language-server",
        dependencies = { "node" },
      },
      require("lib.prettier").tool(),
      require("lib.biome").tool(),
      {
        bin = "cssmodules-language-server",
        mise = "npm:cssmodules-language-server",
        dependencies = { "node" },
      },
    },
    lsps = { "vtsls", "cssmodules_ls" },
    formatter_fts = fts,
    formatters = { "prettier" },
    linter_fts = fts,
    linters = { "biomejs" },
  })
end

return M
