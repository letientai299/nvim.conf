local M = {}

function M.root(bufnr)
  return vim.api
    .nvim_buf_get_name(bufnr)
    :match("^(.*)/%.github/workflows/[^/]+%.ya?ml$")
end

return M
