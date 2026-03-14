local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("csharp", bufnr, {
    tools = {
      { bin = "csharpier", kind = "fmt", mise = "dotnet:csharpier" },
    },
    formatter_fts = "cs",
    formatters = { "csharpier" },
  })
end

return M
