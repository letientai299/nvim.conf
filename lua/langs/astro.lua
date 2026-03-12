local prettier = require("lib.prettier")

require("lib.tools").check("astro", {
  { name = "astro-ls", bin = "astro-ls", kind = "lsp" },
  prettier.tool(),
})

require("lib.lsp").enable("astro")

return {
  prettier.conform("astro"),
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "astro" } },
  },
}
