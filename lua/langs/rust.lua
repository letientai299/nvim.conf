require("lib.tools").check("rust", {
  { name = "rust-analyzer", bin = "rust-analyzer", kind = "lsp" },
  { name = "rustfmt", bin = "rustfmt", kind = "fmt" },
})

vim.lsp.enable("rust_analyzer")

return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        rust = { "rustfmt" },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "rust", "toml" } },
  },
}
