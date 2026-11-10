local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("d2", bufnr, {})
end

return M
