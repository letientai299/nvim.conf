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
  assert(type(Loader._load) == "function", "lazy.nvim Loader._load not found")
  local orig_load = Loader._load
  local installing = {}

  Loader._load = function(plugin, reason, opts)
    if not plugin._.installed then
      if installing[plugin.name] then
        return
      end
      installing[plugin.name] = true
      vim.notify("Installing " .. plugin.name .. "...", vim.log.levels.INFO)
      require("lazy").install({ plugins = { plugin.name }, wait = true })
      installing[plugin.name] = nil
      if not vim.uv.fs_stat(plugin.dir) then
        vim.notify("Failed to install " .. plugin.name, vim.log.levels.ERROR)
        return
      end
      -- Defensive: lazy's git.clone sets this, but guard against edge cases
      -- where the flag wasn't propagated back.
      plugin._.installed = true
      vim.notify(plugin.name .. " installed.", vim.log.levels.INFO)
    end
    return orig_load(plugin, reason, opts)
  end
end

return M
