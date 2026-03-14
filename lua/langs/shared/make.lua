local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("make", bufnr, {})
end

return M
