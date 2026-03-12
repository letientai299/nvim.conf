local prettier = require("lib.prettier")

require("lib.tools").check({ "json", "jsonc" }, {
  { name = "vscode-json-languageserver", bin = "vscode-json-languageserver", kind = "lsp" },
  prettier.tool(),
})

vim.lsp.config("jsonls", {
  settings = {
    json = {
      schemas = require("schemastore").json.schemas(),
      validate = { enable = true },
    },
  },
})
vim.lsp.enable("jsonls")

return {
  prettier.conform({ "json", "jsonc" }),
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "json" } },
  },
}
