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
---@type {cmd: string[], opts?: vim.SystemOpts, cb: fun(ok: boolean, err?: string)}[]
local _queue = {}
local _running = false

local function drain()
  if _running or #_queue == 0 then
    return
  end
  _running = true
  local job = table.remove(_queue, 1)
  run(job.cmd, job.opts, function(ok, err)
    _running = false
    job.cb(ok, err)
    drain()
  end)
end

---@param spec string
---@param opts tool-installer.InstallOpts
---@param callback fun(ok: boolean, err?: string)
function M.install(spec, opts, callback)
  local target = opts.version and (spec .. "@" .. opts.version) or spec
  local cmd = { "mise", "use", "-g", target }
  if opts.force then
    table.insert(cmd, 3, "--force")
  end
  _queue[#_queue + 1] = {
    cmd = cmd,
    opts = {
      env = {
        MISE_EXPERIMENTAL = "1",
      },
    },
    cb = callback,
  }
  drain()
end

return M
