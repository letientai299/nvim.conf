require("lib.tools").check("astro", {
  { name = "astro-ls", bin = "astro-ls", kind = "lsp" },
  { name = "prettier", bin = "prettier", kind = "fmt" },
})

vim.lsp.enable("astro")

return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        astro = { "prettier" },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "astro" } },
  },
}
