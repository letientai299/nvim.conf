-- On-demand plugin cloning for lazy.nvim.
-- Monkey-patches Loader._load so missing plugins auto-install when their
-- lazy-load trigger fires. Self-contained for a future upstream PR.
--
-- Relies on Loader._load(plugin, reason, opts) signature from lazy.nvim
-- stable branch (v11.x as of 2026-03). If lazy.nvim changes this internal
-- API, the patch will need updating.

local M = {}

--- No-op proxy returned by `lazy_require` when the module isn't loaded yet.
--- Silently absorbs indexing and calls so downstream code like
--- `lazy_require("oil").open(path)` becomes a no-op instead of crashing.
local noop_proxy
noop_proxy = setmetatable({}, {
  __index = function()
    return noop_proxy
  end,
  __call = function()
    return noop_proxy
  end,
  __tostring = function()
    return "pending_plugin_proxy"
  end,
})

--- Require a plugin module, returning a no-op proxy if it isn't loaded yet.
--- Use this in `init`, `keys`, and `cmd` callbacks that may run before the
--- plugin is cloned (on-demand install). Once the plugin loads, subsequent
--- calls return the real module.
---@param modname string
---@return table
function M.lazy_require(modname)
  local mod = package.loaded[modname]
  if mod then
    return mod
  end
  local ok, result = pcall(require, modname)
  if ok then
    return result
  end
  return noop_proxy
end

function M.enable()
  local Loader = require("lazy.core.loader")
  local Config = require("lazy.core.config")
  local Util = require("lazy.core.util")
  assert(type(Loader._load) == "function", "lazy.nvim Loader._load not found")
  local orig_load = Loader._load
  ---@type table<string, {reason: table, opts: table?}>
  local pending = {}

  -- Suppress "Command not found" and "Plugin not installed" errors from lazy's
  -- handlers when a plugin is mid-install.
  local suppress_patterns = {
    "^Command `[^`]+` not found after loading",
    "^Plugin [%S]+ is not installed",
  }
  local orig_error = Util.error
  Util.error = function(msg, ...)
    if type(msg) == "string" then
      for name in pairs(pending) do
        if msg:find(name, 1, true) then
          for _, pat in ipairs(suppress_patterns) do
            if msg:find(pat) then
              return
            end
          end
        end
      end
    end
    return orig_error(msg, ...)
  end

  -- Listen for lazy's install completion event to finalize and load.
  vim.api.nvim_create_autocmd("User", {
    pattern = "LazyInstall",
    callback = function()
      for name, ctx in pairs(pending) do
        local plugin = Config.plugins[name]
        if not plugin or not vim.uv.fs_stat(plugin.dir) then
          vim.notify("Failed to install " .. name, vim.log.levels.ERROR, {
            id = "lazy_ondemand_" .. name,
          })
          pending[name] = nil
          goto continue
        end
        plugin._.installed = true
        require("lazy.core.cache").reset(plugin.dir)
        pending[name] = nil
        vim.notify(name .. " installed.", vim.log.levels.INFO, {
          id = "lazy_ondemand_" .. name,
        })
        orig_load(plugin, ctx.reason, ctx.opts)
        ::continue::
      end
    end,
  })

  Loader._load = function(plugin, reason, opts)
    if not plugin._.installed then
      if pending[plugin.name] then
        return
      end
      pending[plugin.name] = { reason = reason, opts = opts }
      vim.notify("Installing " .. plugin.name .. "...", vim.log.levels.INFO, {
        id = "lazy_ondemand_" .. plugin.name,
        timeout = false,
      })
      require("lazy").install({
        plugins = { plugin.name },
        show = false,
      })
      return
    end
    return orig_load(plugin, reason, opts)
  end
end

return M
