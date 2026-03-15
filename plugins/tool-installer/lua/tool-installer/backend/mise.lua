local run = require("tool-installer.backend.run")

local M = {}

local _available ---@type boolean?

function M.available()
  if _available == nil then
    _available = vim.fn.executable("mise") == 1
  end
  return _available
end

---@param spec string
---@param version? string
---@param callback fun(ok: boolean, err?: string)
function M.install(spec, version, callback)
  local target = version and (spec .. "@" .. version) or spec
  run({ "mise", "use", "-g", target }, callback)
end

return M
