local M = {}
local log = require("tool-installer.log")

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
  local function append_stream(data, level)
    if not data or data == "" then
      return
    end
    local lines = vim.split(data, "\n", { plain = true, trimempty = true })
    for _, line in ipairs(lines) do
      log.append(level, "[script:" .. spec .. "] " .. line)
    end
  end

  vim.system({
    path,
  }, {
    text = true,
    stdout = function(_, data)
      append_stream(data, vim.log.levels.INFO)
    end,
    stderr = function(_, data)
      append_stream(data, vim.log.levels.ERROR)
    end,
  }, function(result)
    if result.code == 0 then
      callback(true)
    else
      callback(false, result.stderr or ("exit " .. result.code))
    end
  end)
end

return M
