local M = {}

---@param lnum integer 1-based line number
local function toggle_line(lnum)
  local line = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1]
  if line:match("^(%s*)%- %[x%]") then
    line = line:gsub("^(%s*)%- %[x%]", "%1- [ ]")
  elseif line:match("^(%s*)%- %[ %]") then
    line = line:gsub("^(%s*)%- %[ %]", "%1- [x]")
  elseif line:match("^(%s*)%- ") then
    line = line:gsub("^(%s*)%- (.*)", "%1- [ ] %2")
  end
  vim.api.nvim_buf_set_lines(0, lnum - 1, lnum, false, { line })
end

function M.setup_keymaps()
  vim.keymap.set("n", "<C-Space>", function()
    toggle_line(vim.fn.line("."))
  end, { buffer = true, desc = "Toggle checklist" })

  vim.keymap.set("x", "<C-Space>", function()
    local start = vim.fn.line("v")
    local stop = vim.fn.line(".")
    if start > stop then
      start, stop = stop, start
    end
    for lnum = start, stop do
      toggle_line(lnum)
    end
    vim.cmd("normal! \27") -- exit visual mode
  end, { buffer = true, desc = "Toggle checklist" })
end

return M
