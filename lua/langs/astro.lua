require("lib.tools").check("astro", {
  { name = "astro-ls", bin = "astro-ls", kind = "lsp" },
  { name = "prettierd", bin = "prettierd", kind = "fmt" },
})

vim.lsp.enable("astro")

return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        astro = { "prettierd", "prettier", stop_after_first = true },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "astro" } },
  },
}
