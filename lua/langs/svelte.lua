local prettier = require("lib.prettier")

require("lib.tools").check("svelte", {
  { name = "svelteserver", bin = "svelteserver", kind = "lsp" },
  prettier.tool(),
  { name = "biome", bin = "biome", kind = "lint" },
  { name = "svelte-check", bin = "svelte-check", kind = "check" },
})

vim.lsp.enable("svelte")

return {
  prettier.conform("svelte"),
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
