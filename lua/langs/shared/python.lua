local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("python", bufnr, {
    tools = {
      { bin = "ruff", mise = "ruff" },
    },
    lsp = "ruff",
    formatters = { "ruff_format", "ruff_organize_imports" },
  })
end

return M
