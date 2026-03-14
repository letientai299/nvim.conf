local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("astro", bufnr, {
    tools = {
      { bin = "astro-ls", kind = "lsp", mise = "npm:@astrojs/language-server" },
      require("lib.prettier").tool(),
    },
    lsp = "astro",
    formatters = { "prettier" },
  })
end

return M
