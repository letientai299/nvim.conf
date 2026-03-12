local M = {}

function M.setup(bufnr)
  require("lib.tools").check_now({
    {
      name = "yaml-language-server",
      bin = "yaml-language-server",
      kind = "lsp",
    },
    require("lib.prettier").tool(),
  })

  require("lib.lsp").enable("yamlls", bufnr)

  local registry = require("lib.lang_registry")
  registry.add_formatters("yaml", { "prettier" })
  registry.ensure_parsers({ "yaml" })
end

return M
