local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("astro", bufnr, {
    tools = {
      { name = "astro-ls", bin = "astro-ls", kind = "lsp" },
      require("lib.prettier").tool(),
    },
    lsp = "astro",
    formatters = { "prettier" },
    parsers = { "astro" },
  })
end

return M
