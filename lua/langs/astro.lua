local M = {}

function M.setup(bufnr)
  require("lib.tools").check_now({
    { name = "astro-ls", bin = "astro-ls", kind = "lsp" },
    require("lib.prettier").tool(),
  })

  require("lib.lsp").enable("astro", bufnr)

  local registry = require("lib.lang_registry")
  registry.add_formatters("astro", { "prettier" })
  registry.ensure_parsers({ "astro" })
end

return M
