local M = {}

function M.setup(bufnr)
  require("lib.tools").check_now({
    { name = "lua-language-server", bin = "lua-language-server", kind = "lsp" },
    { name = "stylua", bin = "stylua", kind = "fmt" },
  })

  require("lib.lsp").enable("lua_ls", bufnr)

  local registry = require("lib.lang_registry")
  registry.add_formatters("lua", { "stylua" })
  registry.ensure_parsers({ "lua", "luadoc" })
end

return M
