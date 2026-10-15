vim.opt.rtp:prepend(vim.fn.getcwd())
require("options")
vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })

local buf = vim.api.nvim_get_current_buf()
local win = vim.api.nvim_get_current_win()
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one", "two", "three" })
vim.diagnostic.set(vim.api.nvim_create_namespace("jump-test"), buf, {
  { lnum = 0, col = 0, message = "first diagnostic" },
  { lnum = 2, col = 0, message = "last diagnostic" },
})

for _, case in ipairs({
  { "[d", 1, "first diagnostic" },
  { "]d", 3, "last diagnostic" },
  { "]d", 1, "first diagnostic" },
  { "[d", 3, "last diagnostic" },
}) do
  vim.api.nvim_win_set_cursor(win, { 2, 0 })
  if case[1] == "]d" and case[2] == 1 then
    vim.api.nvim_win_set_cursor(win, { 3, 0 })
  elseif case[1] == "[d" and case[2] == 3 then
    vim.api.nvim_win_set_cursor(win, { 1, 0 })
  end
  vim.cmd.normal(case[1])
  assert(vim.api.nvim_win_get_cursor(win)[1] == case[2], "Wrong jump target")
  local float
  assert(
    vim.wait(1000, function()
      for _, candidate in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_config(candidate).relative ~= "" then
          float = candidate
          return true
        end
      end
      return false
    end),
    "Diagnostic float missing"
  )
  local lines =
    vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(float), 0, -1, false)
  assert(
    table.concat(lines, "\n"):find(case[3], 1, true),
    "Wrong float message"
  )
  assert(vim.api.nvim_get_current_win() == win, "Diagnostic float took focus")
  vim.api.nvim_win_close(float, true)
end

assert(vim.v.errmsg == "", vim.v.errmsg)
print("Diagnostic jumps passed")
