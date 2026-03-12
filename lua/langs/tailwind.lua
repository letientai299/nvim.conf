local fts = { "css", "html", "javascript", "javascriptreact", "typescript", "typescriptreact", "vue", "svelte", "astro", "mdx" }

require("lib.tools").check(fts, {
  { name = "tailwindcss-language-server", bin = "tailwindcss-language-server", kind = "lsp" },
})

vim.lsp.enable("tailwindcss")

return {}
