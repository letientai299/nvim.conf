local M = {}

function M.setup(bufnr)
  require("lib.tools").check_now({
    { name = "docker-langserver", bin = "docker-langserver", kind = "lsp" },
  })

  require("lib.lsp").enable("dockerls", bufnr)
  require("lib.lang_registry").ensure_parsers({ "dockerfile" })
end

return M
