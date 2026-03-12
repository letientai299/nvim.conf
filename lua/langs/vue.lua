local M = {}

function M.setup(bufnr)
  require("lib.tools").check_now({
    { name = "vue-language-server", bin = "vue-language-server", kind = "lsp" },
    require("lib.prettier").tool(),
    { name = "biome", bin = "biome", kind = "lint" },
  })

  require("lib.lsp").enable("vls", bufnr)

  local registry = require("lib.lang_registry")
  registry.add_formatters("vue", { "prettier" })
  registry.add_linter("vue", { "biomejs" })
  registry.ensure_parsers({ "vue" })
end

return M
