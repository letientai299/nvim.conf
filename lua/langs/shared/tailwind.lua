local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("tailwind", bufnr, {
    tools = {
      {
        bin = "tailwindcss-language-server",
        mise = "npm:tailwindcss-language-server",
        dependencies = { "node" },
      },
    },
    lsp = "tailwindcss",
  })
end

return M
