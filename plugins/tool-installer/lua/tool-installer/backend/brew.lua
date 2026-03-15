local run = require("tool-installer.backend.run")

local M = {}

local _available ---@type boolean?

function M.available()
  if _available == nil then
    _available = vim.fn.executable("brew") == 1
  end
  return _available
end

---@param spec string
---@param _ string? unused, brew doesn't support arbitrary versions
---@param callback fun(ok: boolean, err?: string)
function M.install(spec, _, callback)
  run({ "brew", "install", spec }, callback)
end

return M
