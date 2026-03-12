require("lib.tools").check("toml", {
  { name = "taplo", bin = "taplo", kind = "lsp/fmt" },
})

require("lib.lsp").enable("taplo")

return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        toml = { "taplo" },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "toml" } },
  },
}
