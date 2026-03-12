require("lib.tools").check("yaml", {
  { name = "yaml-language-server", bin = "yaml-language-server", kind = "lsp" },
})

vim.lsp.config("yamlls", {
  settings = {
    yaml = {
      schemaStore = { enable = false, url = "" },
      schemas = require("schemastore").yaml.schemas(),
    },
  },
})
vim.lsp.enable("yamlls")

return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        yaml = { "prettier" },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "yaml" } },
  },
}
