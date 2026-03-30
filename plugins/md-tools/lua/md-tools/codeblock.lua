local M = {}

function M.setup_keymaps()
  vim.keymap.set("n", "Q", function()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_buf_set_lines(0, row, row, false, { "```", "", "```" })
    vim.api.nvim_win_set_cursor(0, { row + 2, 3 })
    vim.cmd("startinsert!")
  end, { buffer = true, desc = "Insert code block" })
end

return M
