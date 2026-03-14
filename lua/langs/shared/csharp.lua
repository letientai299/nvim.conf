local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("csharp", bufnr, {
    formatter_fts = "cs",
    formatters = { "csharpier" },
  })
end

return M
