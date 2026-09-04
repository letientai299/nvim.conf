local M = {}

local function diary_dir()
  local note_dir = vim.env.NOTE
  if not note_dir or note_dir == "" then
    vim.notify("$NOTE is not set", vim.log.levels.ERROR)
    return
  end

  local dir = note_dir .. "/diary/" .. os.date("%Y")
  vim.fn.mkdir(dir, "p")
  return dir
end

--- Open today's diary file.
--- Creates the file with a templated date header if it doesn't exist.
function M.note_today()
  local dir = diary_dir()
  if not dir then
    return
  end

  local date = os.date("%Y-%m-%d")
  local day_name = os.date("%A")

  local path = dir .. "/" .. date .. ".md"
  local exists = vim.uv.fs_stat(path) ~= nil

  vim.cmd.edit(path)

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

--- Open this month's diary file.
function M.note_month()
  local dir = diary_dir()
  if not dir then
    return
  end

  vim.cmd.edit(dir .. "/" .. os.date("%Y-%m") .. ".md")
  vim.cmd("$")
end

return M
