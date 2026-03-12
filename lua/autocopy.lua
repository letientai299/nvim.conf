local M = {}

local group = vim.api.nvim_create_augroup("AutoCopy", { clear = true })
local tracked_buf = nil

local function copy_buf()
  if not tracked_buf or not vim.api.nvim_buf_is_valid(tracked_buf) then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(tracked_buf, 0, -1, false)
  vim.fn.setreg("+", table.concat(lines, "\n"))
end

function M.toggle()
  local buf = vim.api.nvim_get_current_buf()
  if tracked_buf == buf then
    tracked_buf = nil
    vim.api.nvim_clear_autocmds({ group = group })
    vim.notify("AutoCopy OFF", vim.log.levels.INFO)
    return
  end

  tracked_buf = buf
  vim.api.nvim_clear_autocmds({ group = group })
  vim.api.nvim_create_autocmd({ "FocusLost", "BufLeave", "WinLeave" }, {
    group = group,
    callback = copy_buf,
  })
  copy_buf()
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then
    name = "[No Name]"
  end
  vim.notify("AutoCopy ON: " .. vim.fn.fnamemodify(name, ":t"), vim.log.levels.INFO)
end

return M
