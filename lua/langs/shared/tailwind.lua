local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("tailwind", bufnr, {
    tools = {
      {
        name = "tailwindcss-language-server",
        bin = "tailwindcss-language-server",
        kind = "lsp",
      },
    },
    lsp = "tailwindcss",
  })
end

return M
