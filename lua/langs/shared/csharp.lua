local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("csharp", bufnr, {
    formatter_fts = "cs",
    formatters = { "csharpier" },
    parsers = { "c_sharp" },
  })
end

return M
