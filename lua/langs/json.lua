require("lib.tools").check({ "json", "jsonc" }, {
  { name = "vscode-json-languageserver", bin = "vscode-json-languageserver", kind = "lsp" },
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
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        json = { "prettier" },
        jsonc = { "prettier" },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "json" } },
  },
}
