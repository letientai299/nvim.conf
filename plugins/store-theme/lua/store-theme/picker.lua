local M = {}

--- Execute a before/after hook string, logging errors at DEBUG level.
local function exec_hook(code)
  if not code or code == "" then
    return
  end
  local chunk, err = load(code)
  if not chunk then
    vim.notify("store-theme hook: " .. err, vim.log.levels.DEBUG)
    return
  end
  local ok, exec_err = pcall(chunk)
  if not ok then
    vim.notify("store-theme hook: " .. exec_err, vim.log.levels.DEBUG)
  end
end

function M.pick()
  local config = require("fzf-lua.config")
  local core = require("fzf-lua.core")
  local shell = require("fzf-lua.shell")
  local store = require("store-theme")

  local opts = config.normalize_opts({}, "colorschemes")
  if not opts then
    return
  end

  local catalog = require("plugins.themes.catalog")
  local themes = catalog.collect_themes()

  local items = {}
  local lookup = {}
  for _, t in ipairs(themes) do
    local name = type(t) == "string" and t or t.name
    items[#items + 1] = name
    lookup[name] = type(t) == "table" and t or { name = t, colorscheme = t }
  end

  -- Capture current state including the full theme entry for hook restoration.
  local current_cs = vim.g.colors_name
  local current_bg = vim.o.background
  local current_entry = current_cs and lookup[current_cs]
  local previewed = false

  -- Live preview via fzf's preview mechanism.
  opts.fzf_opts = opts.fzf_opts or {}
  opts.fzf_opts["--preview-window"] = "nohidden:right:0"
  opts.preview = shell.stringify_data(function(sel)
    if not sel or not sel[1] then
      return
    end
    local theme = lookup[sel[1]]
    if not theme then
      return
    end
    previewed = true
    -- Reset background before each preview to prevent leakage.
    vim.opt.background = "dark"
    exec_hook(theme.before)
    pcall(vim.cmd.colorscheme, theme.colorscheme)
    exec_hook(theme.after)
  end, opts, "{}")

  -- Restore on close/cancel — re-run hooks so side effects are restored.
  opts.winopts = opts.winopts or {}
  local orig_on_close = opts.winopts.on_close
  opts.winopts.on_close = function()
    if previewed then
      vim.o.background = current_bg
      if current_entry then
        exec_hook(current_entry.before)
      end
      pcall(vim.cmd.colorscheme, current_cs)
      if current_entry then
        exec_hook(current_entry.after)
      end
    end
    if orig_on_close then
      orig_on_close()
    end
  end

  opts.actions = {
    ["enter"] = function(selected)
      if not selected or not selected[1] then
        return
      end
      local theme = lookup[selected[1]]
      if theme then
        previewed = false -- skip restore
        store.apply(theme, true)
      end
    end,
    ["ctrl-s"] = function(selected)
      if not selected or not selected[1] then
        return
      end
      local theme = lookup[selected[1]]
      if theme then
        previewed = false -- skip restore
        store.apply(theme, false)
      end
    end,
  }

  core.fzf_exec(items, opts)
end

return M
