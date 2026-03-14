local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("vue", bufnr, {
    tools = {
      {
        bin = "vue-language-server",
        kind = "lsp",
        mise = "npm:@vue/language-server",
      },
      require("lib.prettier").tool(),
      require("lib.biome").tool(),
    },
    lsp = "vls",
    formatters = { "prettier" },
    linters = { "biomejs" },
  })
end

return M
