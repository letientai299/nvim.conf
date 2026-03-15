local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("astro", bufnr, {
    tools = {
      {
        bin = "astro-ls",
        mise = "npm:@astrojs/language-server",
        dependencies = { "node" },
      },
      require("lib.prettier").tool(),
    },
    lsp = "astro",
    formatters = { "prettier" },
  })
end

return M
