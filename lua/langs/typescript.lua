local M = {}

local fts = { "javascript", "javascriptreact", "typescript", "typescriptreact" }

function M.setup(bufnr)
  require("lib.tools").check_now({
    { name = "vtsls", bin = "vtsls", kind = "lsp" },
    require("lib.prettier").tool(),
    { name = "biome", bin = "biome", kind = "lint" },
  })

  require("lib.lsp").enable("vtsls", bufnr)

  local registry = require("lib.lang_registry")
  registry.add_formatters(fts, { "prettier" })
  registry.add_linter(fts, { "biomejs" })
  registry.ensure_parsers({ "javascript", "typescript", "tsx", "jsdoc" })
end

return M
