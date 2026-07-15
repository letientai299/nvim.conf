local M = {}

--- Open today's diary file.
--- Creates the file with a templated date header if it doesn't exist.
function M.note_today()
  local note_dir = vim.env.NOTE
  if not note_dir or note_dir == "" then
    vim.notify("$NOTE is not set", vim.log.levels.ERROR)
    return
  end

  local date = os.date("%Y-%m-%d")
  local year = os.date("%Y")
  local day_name = os.date("%A")

  local dir = note_dir .. "/diary/" .. year
  vim.fn.mkdir(dir, "p")

  local path = dir .. "/" .. date .. ".md"
  local exists = vim.uv.fs_stat(path) ~= nil

  vim.cmd.edit(path)

  -- Append `## <hh:mm>` at the bottom of the buffer, then park the cursor there.
  vim.keymap.set("n", "<leader>vt", function()
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { "## " .. os.date("%H:%M"), "" })
    vim.cmd("$")
  end, { buffer = true, desc = "Notes: append time heading" })

  if not exists then
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      "# " .. date .. " - " .. day_name,
      "",
      "## Goals",
      "",
      "---",
      "",
    })
  end

  -- Place cursor at end of buffer.
  vim.cmd("$")
end

return M
