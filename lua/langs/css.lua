local prettier = require("lib.prettier")

require("lib.tools").check("css", {
  { name = "vscode-css-language-server", bin = "vscode-css-language-server", kind = "lsp" },
  prettier.tool(),
  { name = "biome", bin = "biome", kind = "lint" },
})

require("lib.lsp").enable("cssls")

return {
  prettier.conform({ "css", "scss", "less" }),
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        css = { "biomejs" },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "css", "scss" } },
  },
}
