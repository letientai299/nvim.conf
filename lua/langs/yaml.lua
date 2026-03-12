local prettier = require("lib.prettier")

require("lib.tools").check("yaml", {
  { name = "yaml-language-server", bin = "yaml-language-server", kind = "lsp" },
  prettier.tool(),
})

vim.lsp.config("yamlls", {
  settings = {
    yaml = {
      schemaStore = { enable = false, url = "" },
      schemas = require("schemastore").yaml.schemas(),
    },
  },
})
require("lib.lsp").enable("yamlls")

return {
  prettier.conform("yaml"),
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "yaml" } },
  },
}
