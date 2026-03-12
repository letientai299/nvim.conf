local M = {}

function M.setup(bufnr)
  require("lib.tools").check_now({
    { name = "marksman", bin = "marksman", kind = "lsp" },
    require("lib.prettier").tool(),
    { name = "markdownlint-cli2", bin = "markdownlint-cli2", kind = "lint" },
  })

  require("lib.lsp").enable("marksman", bufnr)

  local registry = require("lib.lang_registry")
  registry.add_formatters({ "markdown", "markdown.mdx" }, { "prettier" })
  registry.add_linter("markdown", { "markdownlint-cli2" })
  registry.ensure_parsers({ "markdown", "markdown_inline" })
end

return M
