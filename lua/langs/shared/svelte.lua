local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("svelte", bufnr, {
    tools = {
      { name = "svelteserver", bin = "svelteserver", kind = "lsp" },
      require("lib.prettier").tool(),
      { name = "biome", bin = "biome", kind = "lint" },
      { name = "svelte-check", bin = "svelte-check", kind = "check" },
    },
    lsp = "svelte",
    formatters = { "prettier" },
    linters = { "biomejs" },
  })
end

return M
