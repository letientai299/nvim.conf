local M = {}

function M.setup(bufnr)
  require("lib.tools").check_now({
    { name = "taplo", bin = "taplo", kind = "lsp/fmt" },
  })

  require("lib.lsp").enable("taplo", bufnr)

  local registry = require("lib.lang_registry")
  registry.add_formatters("toml", { "taplo" })
  registry.ensure_parsers({ "toml" })
end

return M
