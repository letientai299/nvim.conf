local M = {}

function M.setup(bufnr)
  require("lib.tools").check_now({
    { name = "ruff", bin = "ruff", kind = "lsp" },
  })

  require("lib.lsp").enable("ruff", bufnr)

  local registry = require("lib.lang_registry")
  registry.add_formatters("python", { "ruff_format", "ruff_organize_imports" })
  registry.ensure_parsers({ "python", "rst" })
end

return M
