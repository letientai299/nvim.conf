-- On-demand plugin cloning for lazy.nvim.
-- Monkey-patches Loader._load so missing plugins auto-install when their
-- lazy-load trigger fires. Self-contained for a future upstream PR.
--
-- Relies on Loader._load(plugin, reason, opts) signature from lazy.nvim
-- stable branch (v11.x as of 2026-03). If lazy.nvim changes this internal
-- API, the patch will need updating.

local M = {}

function M.enable()
  local Loader = require("lazy.core.loader")
  local Config = require("lazy.core.config")
  local Util = require("lazy.core.util")
  assert(type(Loader._load) == "function", "lazy.nvim Loader._load not found")
  local orig_load = Loader._load
  ---@type table<string, {reason: table, opts: table?}>
  local pending = {}

  -- Suppress "Command not found" and "Plugin not installed" errors from lazy's
  -- handlers when a plugin is mid-install. These fire because the cmd/keys
  -- handler deletes the temp trigger, calls _load (we return early), then
  -- checks for the real command which doesn't exist yet.
  -- Lazy's cmd handler errors with "Command `X` not found after loading `Y`"
  -- and loader errors with "Plugin Y is not installed" when _load returns early
  -- for a pending install. Suppress only these specific patterns.
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
