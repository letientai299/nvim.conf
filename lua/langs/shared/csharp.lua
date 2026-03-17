local M = {}
local csharpier = require("lib.csharpier")

function M.setup(bufnr)
  require("langs.shared.entry").setup("csharp", bufnr, {
    lsp = "roslyn",
    tools = {
      {
        bin = "roslyn",
        script = "install-roslyn-ls.sh",
        dependencies = { "dotnet", "7zip" },
      },
      csharpier.tool(),
    },
    formatter_fts = "cs",
    formatters = { "csharpier" },
  })
end

return M
