require("lib.tools").check("vue", {
  { name = "vue-language-server", bin = "vue-language-server", kind = "lsp" },
  { name = "prettierd", bin = "prettierd", kind = "fmt" },
  { name = "biome", bin = "biome", kind = "lint" },
  { name = "eslint_d", bin = "eslint_d", kind = "lint" },
})

vim.lsp.enable("vue_ls")

return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        vue = { "prettierd", "prettier", stop_after_first = true },
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        vue = { "biomejs", "eslint_d" },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "vue" } },
  },
}
