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
---@param opts tool-installer.InstallOpts version is ignored
---@param callback fun(ok: boolean, err?: string)
function M.install(spec, opts, callback)
  run({ "brew", opts.force and "reinstall" or "install", spec }, callback)
end

return M
