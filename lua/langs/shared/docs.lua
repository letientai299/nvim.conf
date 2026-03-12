local M = {}

function M.markdown(bufnr)
  require("langs.shared.entry").setup("markdown", bufnr, {
    tools = {
      { name = "marksman", bin = "marksman", kind = "lsp" },
      require("lib.prettier").tool(),
      { name = "markdownlint-cli2", bin = "markdownlint-cli2", kind = "lint" },
    },
    lsp = "marksman",
    formatter_fts = { "markdown", "markdown.mdx" },
    formatters = { "prettier" },
    linter_fts = "markdown",
    linters = { "markdownlint-cli2" },
    parsers = { "markdown", "markdown_inline" },
  })
end

function M.mdx(bufnr)
  require("langs.shared.entry").setup("mdx", bufnr, {
    tools = {
      {
        name = "mdx-language-server",
        bin = "mdx-language-server",
        kind = "lsp",
      },
      require("lib.prettier").tool(),
    },
    lsp = "mdx_analyzer",
    formatter_fts = "mdx",
    formatters = { "prettier" },
    parsers = { "markdown", "markdown_inline" },
    once = function()
      vim.treesitter.language.register("markdown", "mdx")
    end,
  })
end

return M
