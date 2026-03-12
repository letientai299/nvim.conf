require("lib.tools").check("svelte", {
  { name = "svelteserver", bin = "svelteserver", kind = "lsp" },
  { name = "prettierd", bin = "prettierd", kind = "fmt" },
  { name = "biome", bin = "biome", kind = "lint" },
  { name = "eslint_d", bin = "eslint_d", kind = "lint" },
  { name = "svelte-check", bin = "svelte-check", kind = "check" },
})

vim.lsp.enable("svelte")

return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        svelte = { "prettierd", "prettier", stop_after_first = true },
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        svelte = { "biomejs", "eslint_d" },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "svelte" } },
  },
}
