local M = {}

--- Execute a before/after hook code string.
--- @param code string?
--- @param label string? chunk name for error messages
--- @param level integer? vim.log.levels (default: WARN)
function M.exec(code, label, level)
  if not code or code == "" then
    return
  end
  level = level or vim.log.levels.WARN
  local chunk, err = load(code, label and ("=" .. label) or nil)
  if not chunk then
    vim.notify("store-theme hook: " .. err, level)
    return
  end
  local ok, exec_err = pcall(chunk)
  if not ok then
    vim.notify("store-theme hook: " .. exec_err, level)
  end
end

return M
