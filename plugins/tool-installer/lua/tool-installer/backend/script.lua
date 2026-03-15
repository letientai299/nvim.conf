local run = require("tool-installer.backend.run")

local M = {}

local _script_dir = ""

function M.available()
  return _script_dir ~= "" and vim.fn.isdirectory(_script_dir) == 1
end

--- Set the base directory for script resolution.
---@param dir string
function M.set_script_dir(dir)
  _script_dir = dir
end

---@param spec string
---@param _ string? unused, scripts don't support versions
---@param callback fun(ok: boolean, err?: string)
function M.install(spec, _, callback)
  local path = _script_dir .. "/" .. spec
  if vim.fn.filereadable(path) ~= 1 then
    callback(false, "script not found: " .. path)
    return
  end
  run({ path }, callback)
end

return M
