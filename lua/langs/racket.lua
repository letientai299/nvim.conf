require("lib.tools").check("racket", {
  { name = "racket-langserver", bin = "racket", kind = "lsp" },
  { name = "raco fmt", bin = "raco", kind = "fmt" },
})

require("lib.lsp").enable("racket_langserver")

return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        racket = { "raco_fmt" },
      },
      formatters = {
        raco_fmt = {
          command = "raco",
          args = { "fmt" },
          stdin = true,
        },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "racket" } },
  },
}
