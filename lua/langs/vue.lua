require("lib.tools").check("vue", {
  { name = "vue-language-server", bin = "vue-language-server", kind = "lsp" },
  { name = "prettier", bin = "prettier", kind = "fmt" },
  { name = "biome", bin = "biome", kind = "lint" },
  { name = "eslint", bin = "vscode-eslint-language-server", kind = "lsp" },
})

vim.lsp.enable("vue_ls")

return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        vue = { "prettier" },
      },
    },
  },
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
