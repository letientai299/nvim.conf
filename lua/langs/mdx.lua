local prettier = require("lib.prettier")

require("lib.tools").check("mdx", {
  { name = "mdx-language-server", bin = "mdx-language-server", kind = "lsp" },
  prettier.tool(),
})

vim.filetype.add({ extension = { mdx = "mdx" } })
vim.treesitter.language.register("markdown", "mdx")

require("lib.lsp").enable("mdx_analyzer")

return {
  prettier.conform("mdx"),
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "markdown", "markdown_inline" } },
  },
}
