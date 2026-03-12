require("lib.tools").check("sh", {
  { name = "bash-language-server", bin = "bash-language-server", kind = "lsp" },
  { name = "shfmt", bin = "shfmt", kind = "fmt" },
})

require("lib.lsp").enable("bashls")

return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        sh = { "shfmt" },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "bash" } },
  },
}
