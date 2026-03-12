local M = {}

function M.setup(bufnr)
  require("lib.tools").check_now({
    {
      name = "tailwindcss-language-server",
      bin = "tailwindcss-language-server",
      kind = "lsp",
    },
  })

  require("lib.lsp").enable("tailwindcss", bufnr)
end

return M
