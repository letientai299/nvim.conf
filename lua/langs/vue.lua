local prettier = require("lib.prettier")

require("lib.tools").check("vue", {
  { name = "vue-language-server", bin = "vue-language-server", kind = "lsp" },
  prettier.tool(),
  { name = "biome", bin = "biome", kind = "lint" },
})

require("lib.lsp").enable("vls")

return {
  prettier.conform("vue"),
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        vue = { "biomejs" },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "vue" } },
  },
}
