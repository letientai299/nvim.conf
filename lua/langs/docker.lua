require("lib.tools").check("dockerfile", {
  { name = "docker-langserver", bin = "docker-langserver", kind = "lsp" },
})

require("lib.lsp").enable("dockerls")

return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "dockerfile" } },
  },
}
