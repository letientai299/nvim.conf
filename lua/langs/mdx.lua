local M = {}

function M.setup(bufnr)
  require("lib.tools").check_now({
    { name = "mdx-language-server", bin = "mdx-language-server", kind = "lsp" },
    require("lib.prettier").tool(),
  })

  vim.treesitter.language.register("markdown", "mdx")
  require("lib.lsp").enable("mdx_analyzer", bufnr)

  local registry = require("lib.lang_registry")
  registry.add_formatters("mdx", { "prettier" })
  registry.ensure_parsers({ "markdown", "markdown_inline" })
end

return M
