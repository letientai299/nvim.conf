local M = {}

--- Schedule vim.lsp.enable so it doesn't block the initial render.
function M.enable(name)
  vim.schedule(function() vim.lsp.enable(name) end)
end

return M
