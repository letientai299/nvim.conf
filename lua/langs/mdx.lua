require("lib.tools").check("mdx", {
  { name = "mdx-language-server", bin = "mdx-language-server", kind = "lsp" },
  { name = "prettier", bin = "prettier", kind = "fmt" },
})

vim.filetype.add({ extension = { mdx = "mdx" } })
vim.treesitter.language.register("markdown", "mdx")

vim.lsp.enable("mdx_analyzer")

return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        mdx = { "prettier" },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "markdown", "markdown_inline" } },
  },
}
