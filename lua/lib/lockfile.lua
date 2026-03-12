local M = {}

--- Strip local plugin entries from lazy-lock.json and cache their names
--- for the git pre-commit hook.
function M.strip_local_plugins()
  local config = require("lazy.core.config")

  local local_names = {}
  for name, plugin in pairs(config.plugins) do
    if plugin._.module and plugin._.module:match("^local%.plugins") then
      local_names[#local_names + 1] = name
    end
  end
  if #local_names == 0 then return end
  table.sort(local_names)

  -- Read lockfile
  local lockfile = config.options.lockfile
  local f = io.open(lockfile, "r")
  if not f then return end
  local ok, data = pcall(vim.json.decode, f:read("*a"))
  f:close()
  if not ok then return end

  -- Remove local plugin entries
  for _, name in ipairs(local_names) do
    data[name] = nil
  end

  -- Write back in lazy.nvim's sorted one-entry-per-line format
  local keys = vim.tbl_keys(data)
  table.sort(keys)
  local lines = {}
  for i, key in ipairs(keys) do
    local comma = i < #keys and "," or ""
    lines[#lines + 1] = ("  %s: %s%s"):format(vim.json.encode(key), vim.json.encode(data[key]), comma)
  end
  f = io.open(lockfile, "w")
  f:write("{\n" .. table.concat(lines, "\n") .. "\n}\n")
  f:close()

  -- Cache names for the git pre-commit hook
  local cache = vim.fn.stdpath("config") .. "/.local-plugin-names"
  f = io.open(cache, "w")
  f:write(table.concat(local_names, "\n") .. "\n")
  f:close()
end

return M
