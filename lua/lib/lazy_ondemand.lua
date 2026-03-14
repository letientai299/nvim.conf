-- On-demand plugin cloning for lazy.nvim.
--
-- Monkey-patches Loader._load so missing plugins auto-install when their
-- lazy-load trigger fires (event, cmd, keys, ft, etc.). The trigger is
-- dropped — the plugin loads only after the async clone finishes and a
-- LazyInstall event fires.
--
-- ## Concurrency model
--
-- Each uninstalled plugin gets its own `require("lazy").install()` call,
-- which creates a separate async runner. Runners clone in parallel, but
-- each fires a **separate** LazyInstall event on completion. Because our
-- LazyInstall handler sees ALL pending plugins (not just the one whose
-- runner finished), it must distinguish "installed" from "still cloning".
-- Lazy.nvim writes a `.cloning` marker file (`plugin.dir .. ".cloning"`)
-- before git-clone starts and removes it on success, so we use that as a
-- ready check.
--
-- ## Cache invalidation
--
-- Lazy.nvim replaces Neovim's default `vim._load_package` loader with its
-- own cache-based loader (`lazy.core.cache`). The cache indexes each rtp
-- directory's `lua/` tree on first access and memoizes the result. After
-- cloning a new plugin we must call `cache.reset(plugin.dir)` to clear
-- the stale (empty) index so `require()` re-scans and finds modules.
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

  local Git = require("lazy.manage.git")

  --- Mark a freshly-cloned plugin as installed and clear its module cache
  --- so that `require()` re-scans `plugin.dir/lua/` on next access.
  --- Returns false if the clone left no valid git commit (lock.update
  --- would crash with "commit is nil").
  local function finalize_install(plugin)
    local info = Git.info(plugin.dir)
    if not info or not info.commit then
      return false
    end
    plugin._.installed = true
    require("lazy.core.cache").reset(plugin.dir)
    return true
  end

  --- Install any missing dependencies of `plugin` (parallel clone, blocking
  --- wait) so that `config` can safely `require()` dependency modules.
  local function ensure_deps_installed(plugin)
    if not plugin.dependencies then
      return
    end
    local to_clone = {}
    for _, dep_name in ipairs(plugin.dependencies) do
      local dep = Config.plugins[dep_name]
      if not dep or dep._.installed then
        goto continue
      end
      if vim.uv.fs_stat(dep.dir) and finalize_install(dep) then
        pending[dep.name] = nil
      else
        to_clone[#to_clone + 1] = dep.name
      end
      ::continue::
    end
    if #to_clone == 0 then
      return
    end
    vim.notify(
      "Installing " .. table.concat(to_clone, ", ") .. "...",
      vim.log.levels.INFO
    )
    require("lazy").install({
      plugins = to_clone,
      wait = true,
      show = false,
    })
    for _, name in ipairs(to_clone) do
      local dep = Config.plugins[name]
      if dep and vim.uv.fs_stat(dep.dir) and finalize_install(dep) then
        pending[name] = nil
        vim.notify(name .. " installed.", vim.log.levels.INFO)
      else
        vim.notify("Failed to install dep " .. name, vim.log.levels.ERROR)
      end
    end
  end

  --- Check whether `plugin` is ready to load after an install event.
  --- Returns true when the clone completed (directory exists, no marker).
  --- Returns false when still cloning (retry later) or permanently failed.
  --- Removes permanently-failed plugins from `pending` and notifies.
  local function is_clone_ready(name, plugin)
    -- Marker present → git-clone still running in another async runner.
    -- Leave in pending; the next LazyInstall event will re-check.
    if vim.uv.fs_stat(plugin.dir .. ".cloning") then
      return false
    end
    -- No directory and no marker → install failed permanently.
    if not vim.uv.fs_stat(plugin.dir) then
      vim.notify("Failed to install " .. name, vim.log.levels.ERROR, {
        id = "lazy_ondemand_" .. name,
      })
      pending[name] = nil
      return false
    end
    return true
  end

  -- Suppress "Command not found" and "Plugin not installed" errors from
  -- lazy's handlers when a plugin is mid-install.
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

  -- Listen for lazy's install-complete event.
  --
  -- Each async runner fires LazyInstall independently, so this callback
  -- may run multiple times. On each invocation we:
  --   1. Snapshot which pending plugins are ready (clone finished).
  --   2. Load them outside the snapshot loop — orig_load may trigger
  --      dependency loading that inserts NEW keys into `pending` via the
  --      patched _load, and mutating a table during pairs() is undefined.
  --   3. Leave still-cloning plugins in `pending` for the next event.
  vim.api.nvim_create_autocmd("User", {
    pattern = "LazyInstall",
    callback = function()
      local ready = {}
      for name, ctx in pairs(pending) do
        local plugin = Config.plugins[name]
        if not plugin then
          pending[name] = nil
        elseif is_clone_ready(name, plugin) then
          ready[#ready + 1] = { name = name, plugin = plugin, ctx = ctx }
        end
      end

      for _, entry in ipairs(ready) do
        if not finalize_install(entry.plugin) then
          vim.notify(
            "Failed to finalize " .. entry.name .. " (no commit)",
            vim.log.levels.ERROR,
            { id = "lazy_ondemand_" .. entry.name }
          )
          pending[entry.name] = nil
          goto continue
        end
        pending[entry.name] = nil
        vim.notify(entry.name .. " installed.", vim.log.levels.INFO, {
          id = "lazy_ondemand_" .. entry.name,
        })
        ensure_deps_installed(entry.plugin)
        -- Guard: the inner LazyInstall handler (fired during
        -- ensure_deps_installed's blocking wait) may have already loaded
        -- this plugin via coroutine re-entrancy.
        if not entry.plugin._.loaded then
          orig_load(entry.plugin, entry.ctx.reason, entry.ctx.opts)
        end
        ::continue::
      end
    end,
  })

  -- Patch colorscheme handler: the original skips uninstalled plugins
  -- because it checks plugin.dir/colors/*.lua on disk. For on-demand
  -- install we match by theme name against plugin specs and install
  -- synchronously (blocking) so the colorscheme applies immediately.
  local orig_colorscheme = Loader.colorscheme
  Loader.colorscheme = function(name)
    orig_colorscheme(name)
    if vim.g.colors_name == name then
      return
    end

    for _, plugin in pairs(Config.plugins) do
      if plugin._.installed then
        goto continue
      end
      local dominated = false
      for _, theme in ipairs(plugin.themes or {}) do
        local cs = type(theme) == "string" and theme or theme.colorscheme
        if cs == name then
          dominated = true
          break
        end
      end
      if dominated then
        vim.notify("Installing " .. plugin.name .. "...", vim.log.levels.INFO)
        require("lazy").install({
          plugins = { plugin.name },
          wait = true,
          show = false,
        })
        if vim.uv.fs_stat(plugin.dir) and finalize_install(plugin) then
          vim.notify(plugin.name .. " installed.", vim.log.levels.INFO)
          return Loader.load(plugin, { colorscheme = name })
        end
        vim.notify("Failed to install " .. plugin.name, vim.log.levels.ERROR)
        return
      end
      ::continue::
    end
  end

  -- Intercept _load for uninstalled plugins: start an async clone and
  -- stash the trigger context. The plugin will be loaded for real when
  -- the LazyInstall handler picks it up after the clone finishes.
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
