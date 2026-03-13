local M = {}

--- @return { name: string, bin: string, kind: string }
function M.tool()
  return { name = "prettier", bin = "prettier", kind = "fmt" }
end

--- Build a conform.nvim spec that maps filetypes to prettier.
--- @param fts string|string[]
--- @return table lazy.nvim plugin spec
function M.conform(fts)
  if type(fts) == "string" then
    fts = { fts }
  end
  local by_ft = {}
  for _, ft in ipairs(fts) do
    by_ft[ft] = { "prettier" }
  end
  return {
    "stevearc/conform.nvim",
    opts = { formatters_by_ft = by_ft },
  }
end

return M
