local prettier = require("lib.prettier")

require("lib.tools").check("html", {
  { name = "vscode-html-language-server", bin = "vscode-html-language-server", kind = "lsp" },
  prettier.tool(),
})

vim.lsp.enable("html")

return {
  prettier.conform("html"),
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "html" } },
  },
}
