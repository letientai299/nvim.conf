require("lib.tools").check("svelte", {
  { name = "svelteserver", bin = "svelteserver", kind = "lsp" },
  { name = "prettier", bin = "prettier", kind = "fmt" },
  { name = "biome", bin = "biome", kind = "lint" },
  { name = "eslint", bin = "vscode-eslint-language-server", kind = "lsp" },
  { name = "svelte-check", bin = "svelte-check", kind = "check" },
})

vim.lsp.enable("svelte")

return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        svelte = { "prettier" },
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        svelte = { "biomejs" },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "svelte" } },
  },
}
