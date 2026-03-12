local prettier = require("lib.prettier")

require("lib.tools").check("markdown", {
  { name = "marksman", bin = "marksman", kind = "lsp" },
  prettier.tool(),
  { name = "markdownlint-cli2", bin = "markdownlint-cli2", kind = "lint" },
})

vim.lsp.enable("marksman")

return {
  prettier.conform("markdown"),
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
