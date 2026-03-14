local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("tailwind", bufnr, {
    tools = {
      {
        bin = "tailwindcss-language-server",
        kind = "lsp",
        mise = "npm:tailwindcss-language-server",
      },
    },
    lsp = "tailwindcss",
  })
end

return M
