local M = {}

local MAX_ENTRIES = 1000
local TRIM_TO = 900
local _entries = {} ---@type string[]
local _buf = nil ---@type integer?
local _win = nil ---@type integer?
local _refresh_pending = false

local function request_refresh()
  if not _buf then
    return
  end
  if vim.in_fast_event() then
    if _refresh_pending then
      return
    end
    _refresh_pending = true
    vim.schedule(function()
      _refresh_pending = false
      pcall(M.refresh)
    end)
    return
  end
  if not (_win and vim.api.nvim_win_is_valid(_win)) then
    return
  end
  M.refresh()
end

local function trim_entries()
  if #_entries <= MAX_ENTRIES then
    return
  end
  _entries = vim.list_slice(_entries, #_entries - TRIM_TO + 1, #_entries)
end

---@param level integer
---@return string
local function level_name(level)
  if level == vim.log.levels.ERROR then
    return "ERROR"
  end
  if level == vim.log.levels.WARN then
    return "WARN"
  end
  if level == vim.log.levels.DEBUG then
    return "DEBUG"
  end
  return "INFO"
end

---@param level integer
---@param message string
function M.append(level, message)
  local ts = os.date("%H:%M:%S")
  local text = tostring(message)
  local prefix = string.format("[%s] %-5s ", ts, level_name(level))
  local parts = vim.split(text, "\n", { plain = true })
  for _, part in ipairs(parts) do
    _entries[#_entries + 1] = prefix .. part
  end
  trim_entries()
  request_refresh()
end

---@return string[]
function M.lines()
  if #_entries == 0 then
    return { "No tool-installer logs yet." }
  end
  return vim.list_slice(_entries, 1, #_entries)
end

function M.refresh()
  if not (_buf and vim.api.nvim_buf_is_valid(_buf)) then
    return
  end
  local lines = #_entries == 0 and { "No tool-installer logs yet." } or _entries
  vim.bo[_buf].modifiable = true
  local ok = pcall(vim.api.nvim_buf_set_lines, _buf, 0, -1, false, lines)
  if not ok or not vim.api.nvim_buf_is_valid(_buf) then
    return
  end
  vim.bo[_buf].modified = false
  vim.bo[_buf].modifiable = false
  if _win and vim.api.nvim_win_is_valid(_win) then
    pcall(
      vim.api.nvim_win_set_cursor,
      _win,
      { vim.api.nvim_buf_line_count(_buf), 0 }
    )
  end
end

function M.open()
  if not (_buf and vim.api.nvim_buf_is_valid(_buf)) then
    _buf = vim.api.nvim_create_buf(false, true)
    vim.bo[_buf].buftype = "nofile"
    vim.bo[_buf].bufhidden = "hide"
    vim.bo[_buf].swapfile = false
    vim.bo[_buf].filetype = "toolinstallerlog"
    vim.bo[_buf].modifiable = false
    vim.api.nvim_buf_set_name(_buf, "tool-installer://log")
  end

  if _win and vim.api.nvim_win_is_valid(_win) then
    vim.api.nvim_set_current_win(_win)
  else
    vim.cmd("botright 12split")
    _win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(_win, _buf)
    vim.wo[_win].number = false
    vim.wo[_win].relativenumber = false
    vim.wo[_win].signcolumn = "no"
    vim.wo[_win].wrap = false
  end

  M.refresh()
end

return M
