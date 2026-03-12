local fts = { "javascript", "javascriptreact", "typescript", "typescriptreact" }

require("lib.tools").check(fts, {
  { name = "cssmodules-language-server", bin = "cssmodules-language-server", kind = "lsp" },
})

vim.lsp.enable("cssmodules_ls")

return {}
