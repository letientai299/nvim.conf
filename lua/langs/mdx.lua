require("lib.tools").check("mdx", {
  { name = "mdx-language-server", bin = "mdx-language-server", kind = "lsp" },
  { name = "prettierd", bin = "prettierd", kind = "fmt" },
})

vim.lsp.enable("mdx_analyzer")

return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        mdx = { "prettierd", "prettier", stop_after_first = true },
      },
    },
  },
}
