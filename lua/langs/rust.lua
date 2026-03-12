local M = {}

function M.setup(bufnr)
  require("lib.tools").check_now({
    { name = "rust-analyzer", bin = "rust-analyzer", kind = "lsp" },
    { name = "rustfmt", bin = "rustfmt", kind = "fmt" },
  })

  require("lib.lsp").enable("rust_analyzer", bufnr)

  local registry = require("lib.lang_registry")
  registry.add_formatters("rust", { "rustfmt" })
  registry.ensure_parsers({ "rust", "toml" })
end

return M
