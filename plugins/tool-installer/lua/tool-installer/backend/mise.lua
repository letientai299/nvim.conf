local run = require("tool-installer.backend.run")

local M = {}

local _available ---@type boolean?

function M.available()
  if _available == nil then
    _available = vim.fn.executable("mise") == 1
  end
  return _available
end

--- Serialize mise calls to prevent concurrent writes to config.toml.
---@type {cmd: string[], cb: fun(ok: boolean, err?: string)}[]
local _queue = {}
local _running = false

local function drain()
  if _running or #_queue == 0 then
    return
  end
  _running = true
  local job = table.remove(_queue, 1)
  run(job.cmd, function(ok, err)
    _running = false
    job.cb(ok, err)
    drain()
  end)
end

---@param spec string
---@param version? string
---@param callback fun(ok: boolean, err?: string)
function M.install(spec, version, callback)
  local target = version and (spec .. "@" .. version) or spec
  _queue[#_queue + 1] = { cmd = { "mise", "use", "-g", target }, cb = callback }
  drain()
end

return M
