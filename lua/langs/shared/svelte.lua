local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("svelte", bufnr, {
    tools = {
      {
        bin = "svelteserver",
        mise = "npm:svelte-language-server",
        dependencies = { "node" },
      },
      require("lib.prettier").tool(),
      require("lib.biome").tool(),
      {
        bin = "svelte-check",
        mise = "npm:svelte-check",
        dependencies = { "node" },
      },
    },
    lsp = "svelte",
    formatters = { "prettier" },
    linters = { "biomejs" },
  })
end

return M
