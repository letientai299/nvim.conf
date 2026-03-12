-- Daily notes: NoteToday command and <leader>td keymap

local M = {}

--- Append a timestamped section to today's diary file.
--- Creates the file with a date header if it doesn't exist.
function M.note_today()
  local note_dir = vim.env.NOTE
  if not note_dir or note_dir == "" then
    vim.notify("$NOTE is not set", vim.log.levels.ERROR)
    return
  end

  local date = os.date("%Y-%m-%d")
  local year = os.date("%Y")
  local day_name = os.date("%A")
  local time = os.date("%H:%M")

  local dir = note_dir .. "/diary/" .. year
  vim.fn.mkdir(dir, "p")

  local path = dir .. "/" .. date .. ".md"
  local exists = vim.uv.fs_stat(path) ~= nil

  vim.cmd.edit(path)

  if not exists then
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      "# " .. date .. " - " .. day_name,
      "",
      "## " .. time,
      "",
    })
  else
    local last = vim.api.nvim_buf_line_count(0)
    local append = { "", "## " .. time, "" }
    vim.api.nvim_buf_set_lines(0, last, last, false, append)
  end

  -- Place cursor at end of buffer.
  vim.cmd("$")
end

return M
