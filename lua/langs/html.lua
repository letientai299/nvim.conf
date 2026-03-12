local M = {}

function M.setup(bufnr)
  require("lib.tools").check_now({
    {
      name = "vscode-html-language-server",
      bin = "vscode-html-language-server",
      kind = "lsp",
    },
    require("lib.prettier").tool(),
  })

  require("lib.lsp").enable("html", bufnr)

  local registry = require("lib.lang_registry")
  registry.add_formatters("html", { "prettier" })
  registry.ensure_parsers({ "html" })
end

return M
