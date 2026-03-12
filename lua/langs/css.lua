local M = {}

function M.setup(bufnr)
  require("lib.tools").check_now({
    {
      name = "vscode-css-language-server",
      bin = "vscode-css-language-server",
      kind = "lsp",
    },
    require("lib.prettier").tool(),
    { name = "biome", bin = "biome", kind = "lint" },
  })

  require("lib.lsp").enable("cssls", bufnr)

  local registry = require("lib.lang_registry")
  registry.add_formatters({ "css", "scss", "less" }, { "prettier" })
  registry.add_linter("css", { "biomejs" })
  registry.ensure_parsers({ "css", "scss" })
end

return M
