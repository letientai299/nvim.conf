require("lib.tools").check("html", {
  { name = "vscode-html-language-server", bin = "vscode-html-language-server", kind = "lsp" },
  { name = "prettierd", bin = "prettierd", kind = "fmt" },
})

vim.lsp.enable("html")

return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        html = { "prettierd", "prettier", stop_after_first = true },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "html" } },
  },
}
