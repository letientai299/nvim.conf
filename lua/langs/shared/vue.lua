local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("vue", bufnr, {
    tools = {
      {
        name = "vue-language-server",
        bin = "vue-language-server",
        kind = "lsp",
      },
      require("lib.prettier").tool(),
      { name = "biome", bin = "biome", kind = "lint" },
    },
    lsp = "vls",
    formatters = { "prettier" },
    linters = { "biomejs" },
    parsers = { "vue" },
  })
end

return M
