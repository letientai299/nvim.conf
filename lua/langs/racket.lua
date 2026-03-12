local M = {}

function M.setup(bufnr)
  require("lib.tools").check_now({
    { name = "racket-langserver", bin = "racket", kind = "lsp" },
    { name = "raco fmt", bin = "raco", kind = "fmt" },
  })

  require("lib.lsp").enable("racket_langserver", bufnr)

  local registry = require("lib.lang_registry")
  registry.add_formatter("raco_fmt", {
    command = "raco",
    args = { "fmt" },
    stdin = true,
  })
  registry.add_formatters("racket", { "raco_fmt" })
  registry.ensure_parsers({ "racket" })
end

return M
