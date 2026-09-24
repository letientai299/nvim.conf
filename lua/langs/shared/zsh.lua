local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("zsh", bufnr, {})
end

return M
