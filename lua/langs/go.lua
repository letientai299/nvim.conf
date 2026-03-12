require("lib.tools").check("go", {
  { name = "gopls", bin = "gopls", kind = "lsp" },
  { name = "goimports", bin = "goimports", kind = "fmt" },
  { name = "gofumpt", bin = "gofumpt", kind = "fmt" },
  { name = "golangci-lint", bin = "golangci-lint", kind = "lint" },
})

require("lib.lsp").enable("gopls")

return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        go = { "goimports", "gofumpt" },
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        go = { "golangcilint" },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "go", "gomod", "gosum" } },
  },
}
