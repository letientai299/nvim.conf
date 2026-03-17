local M = {}

local pending = {} ---@type table<integer, table<string, true>>

---@param bufnr integer
---@param key string
---@param delay_ms integer
---@param callback fun(bufnr: integer)
function M.schedule(bufnr, key, delay_ms, callback)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local by_buf = pending[bufnr]
  if not by_buf then
    by_buf = {}
    pending[bufnr] = by_buf
  end

  if by_buf[key] then
    return
  end
  by_buf[key] = true

  vim.defer_fn(function()
    local state = pending[bufnr]
    if state then
      state[key] = nil
      if vim.tbl_isempty(state) then
        pending[bufnr] = nil
      end
    end

    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    callback(bufnr)
  end, delay_ms)
end

return M
