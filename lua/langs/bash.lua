local M = {}

function M.setup(bufnr)
  require("lib.tools").check_now({
    {
      name = "bash-language-server",
      bin = "bash-language-server",
      kind = "lsp",
    },
    { name = "shfmt", bin = "shfmt", kind = "fmt" },
  })

  require("lib.lsp").enable("bashls", bufnr)

  local registry = require("lib.lang_registry")
  registry.add_formatters({ "bash", "sh", "zsh" }, { "shfmt" })
  registry.ensure_parsers({ "bash" })
end

return M
