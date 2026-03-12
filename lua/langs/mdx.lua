require("lib.tools").check("mdx", {
  { name = "mdx-language-server", bin = "mdx-language-server", kind = "lsp" },
  { name = "prettier", bin = "prettier", kind = "fmt" },
})

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
}
