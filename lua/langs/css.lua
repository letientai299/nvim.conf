require("lib.tools").check("css", {
  { name = "vscode-css-language-server", bin = "vscode-css-language-server", kind = "lsp" },
  { name = "prettier", bin = "prettier", kind = "fmt" },
  { name = "biome", bin = "biome", kind = "lint" },
})

vim.lsp.enable("cssls")

return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        css = { "prettier" },
        scss = { "prettier" },
        less = { "prettier" },
      },
    },
  },
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
