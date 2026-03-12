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
        json = { "prettierd", "prettier", stop_after_first = true },
        jsonc = { "prettierd", "prettier", stop_after_first = true },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "json", "jsonc" } },
  },
}
