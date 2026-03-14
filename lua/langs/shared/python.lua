local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("python", bufnr, {
    tools = {
      { name = "ruff", bin = "ruff", kind = "lsp" },
    },
    lsp = "ruff",
    formatters = { "ruff_format", "ruff_organize_imports" },
  })
end

return M
