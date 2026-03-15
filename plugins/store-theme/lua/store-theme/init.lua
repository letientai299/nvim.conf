local M = {}

local cache = require("store-theme.cache")
local hook = require("store-theme.hook")

local state_dir = vim.fn.stdpath("state") .. "/store"
local state_path = state_dir .. "/theme.lua"

--- Find the lazy.nvim plugin name that owns a colorscheme.
local function find_plugin(colorscheme)
  local ok, catalog = pcall(require, "plugins.themes.catalog")
  if not ok then
    return nil
  end

  for _, spec in ipairs(catalog.load_specs()) do
    for _, theme in ipairs(spec.themes or {}) do
      local name = type(theme) == "string" and theme or theme.colorscheme
      if name == colorscheme then
        local plugin = spec.name
        if type(plugin) == "string" and plugin ~= "" then
          return plugin
        end
        local source = spec[1]
        if type(source) == "string" and source ~= "" then
          return source:match("/([^/]+)$") or source
        end
        return nil
      end
    end
  end
end

--- Persist a theme entry to the state file.
function M.save(entry)
  vim.fn.mkdir(state_dir, "p")

  local colorscheme = entry.colorscheme
  local plugin = entry.plugin or find_plugin(colorscheme) or ""
  local before = entry.before or ""
  local after = entry.after or ""

  local lines = {
    "-- Auto-generated theme state.",
    "return {",
    string.format("  colorscheme = %q,", colorscheme),
    string.format("  before = %q,", before),
    string.format("  after = %q,", after),
    string.format("  plugin = %q,", plugin),
    "}",
  }

  local f = io.open(state_path, "w")
  if not f then
    vim.notify(
      "store-theme: failed to write " .. state_path,
      vim.log.levels.ERROR
    )
    return
  end
  f:write(table.concat(lines, "\n"))
  f:write("\n")
  f:close()

  -- Delete stale hl cache immediately so a crash between save and scheduled
  -- write never leaves init.lua trusting an outdated cache on next startup.
  cache.invalidate()
  cache.schedule_write(colorscheme)
end

--- Apply a theme. If persist is true, also save to disk.
function M.apply(entry, persist)
  hook.exec(entry.before, "theme.before")
  vim.cmd.colorscheme(entry.colorscheme)
  hook.exec(entry.after, "theme.after")

  if persist then
    M.save(entry)
  end
end

--- Open the fzf-lua colorschemes picker.
function M.pick()
  require("store-theme.picker").pick()
end

return M
