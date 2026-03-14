local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("svelte", bufnr, {
    tools = {
      {
        bin = "svelteserver",
        kind = "lsp",
        mise = "npm:svelte-language-server",
      },
      require("lib.prettier").tool(),
      require("lib.biome").tool(),
      { bin = "svelte-check", kind = "check", mise = "npm:svelte-check" },
    },
    lsp = "svelte",
    formatters = { "prettier" },
    linters = { "biomejs" },
  })
end

return M
