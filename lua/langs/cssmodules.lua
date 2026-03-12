local M = {}

function M.setup(bufnr)
  require("lib.tools").check_now({
    {
      name = "cssmodules-language-server",
      bin = "cssmodules-language-server",
      kind = "lsp",
    },
  })

  require("lib.lsp").enable("cssmodules_ls", bufnr)
end

return M
