require("lib.tools").check("markdown", {
  { name = "marksman", bin = "marksman", kind = "lsp" },
  { name = "prettier", bin = "prettier", kind = "fmt" },
  { name = "markdownlint-cli2", bin = "markdownlint-cli2", kind = "lint" },
})

vim.lsp.enable("marksman")

return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        markdown = { "prettier" },
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        markdown = { "markdownlint-cli2" },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "markdown", "markdown_inline" } },
  },
}
