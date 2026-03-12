local M = {}

function M.setup(bufnr)
  require("lib.tools").check_now({
    { name = "svelteserver", bin = "svelteserver", kind = "lsp" },
    require("lib.prettier").tool(),
    { name = "biome", bin = "biome", kind = "lint" },
    { name = "svelte-check", bin = "svelte-check", kind = "check" },
  })

  require("lib.lsp").enable("svelte", bufnr)

  local registry = require("lib.lang_registry")
  registry.add_formatters("svelte", { "prettier" })
  registry.add_linter("svelte", { "biomejs" })
  registry.ensure_parsers({ "svelte" })
end

return M
