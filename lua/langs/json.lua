local M = {}

function M.setup(bufnr)
  require("lib.tools").check_now({
    {
      name = "vscode-json-languageserver",
      bin = "vscode-json-languageserver",
      kind = "lsp",
    },
    require("lib.prettier").tool(),
  })

  require("lib.lsp").enable("jsonls", bufnr)

  local registry = require("lib.lang_registry")
  registry.add_formatters({ "json", "jsonc" }, { "prettier" })
  registry.ensure_parsers({ "json" })
end

return M
