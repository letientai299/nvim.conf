local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("python", bufnr, {
    tools = {
      { bin = "ruff", mise = "ruff" },
      { bin = "ty", mise = "ty" },
    },
    -- ruff: lint + format. ty: type checking, hover, go-to-def, completion.
    lsps = { "ruff", "ty" },
    formatters = { "ruff_format", "ruff_organize_imports" },
  })
end

return M
