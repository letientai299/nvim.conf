local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("csharp", bufnr, {
    tools = {
      {
        bin = "csharpier",
        mise = "dotnet:csharpier",
        dependencies = { "dotnet" },
      },
    },
    formatter_fts = "cs",
    formatters = { "csharpier" },
  })
end

return M
