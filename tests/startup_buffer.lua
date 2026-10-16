local startup = vim.api.nvim_get_current_buf()
local case = vim.env.STARTUP_CASE or "empty"
vim.o.hidden = true

if case == "shared-window" then
  local original = vim.api.nvim_get_current_win()
  vim.cmd.split()
  vim.cmd.edit("init.lua")
  local target = vim.api.nvim_get_current_buf()
  vim.api.nvim_set_current_win(original)
  vim.api.nvim_buf_set_lines(startup, 0, -1, false, { "keep this text" })
  vim.api.nvim_win_set_buf(original, target)
else
  if case == "modified" or case == "unmodified-text" then
    vim.api.nvim_buf_set_lines(startup, 0, -1, false, { "keep this text" })
    vim.bo[startup].modified = case == "modified"
  elseif case == "named" then
    vim.api.nvim_buf_set_name(startup, "retained.txt")
  end
  local target = vim.fn.bufadd(vim.fn.getcwd() .. "/init.lua")
  vim.api.nvim_set_current_buf(target)
  if case == "reentered" then
    vim.api.nvim_set_current_buf(startup)
  elseif case == "changed-before-cleanup" then
    vim.api.nvim_buf_set_lines(startup, 0, -1, false, { "keep this text" })
  end
end

local settled = false
vim.schedule(function()
  settled = true
end)
assert(
  vim.wait(1000, function()
    return settled
  end),
  "Cleanup callback timed out"
)
assert(
  vim.api.nvim_buf_is_valid(startup) == (case ~= "empty"),
  "Wrong startup buffer retention"
)
if vim.api.nvim_buf_is_valid(startup) then
  assert(vim.bo[startup].bufhidden == "", "Startup buffer became disposable")
end
assert(vim.v.errmsg == "", vim.v.errmsg)
print(case .. " passed")
