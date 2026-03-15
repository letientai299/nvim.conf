local M = {}

function M.pick()
  local config = require("fzf-lua.config")
  local core = require("fzf-lua.core")
  local shell = require("fzf-lua.shell")
  local store = require("store-theme")
  local hook = require("store-theme.hook")

  local opts = config.normalize_opts({ locate = true }, "colorschemes")
  if not opts then
    return
  end

  local catalog = require("plugins.themes.catalog")
  local themes = catalog.collect_themes()

  local items = {}
  local lookup = {}
  local current_cs = vim.g.colors_name
  local current_entry = nil
  local current_pos = nil

  for _, t in ipairs(themes) do
    local name = type(t) == "string" and t or t.name
    local entry = type(t) == "table" and t or { name = t, colorscheme = t }
    lookup[name] = entry
    items[#items + 1] = name
    if entry.colorscheme == current_cs then
      current_entry = entry
      current_pos = #items
    end
  end

  -- Capture current state for hook restoration on cancel.
  local current_bg = vim.o.background
  local previewed = false

  -- Live preview via fzf's preview mechanism.
  opts.fzf_opts = opts.fzf_opts or {}
  opts.fzf_opts["--preview-window"] = "nohidden:right:0"
  if current_pos then
    opts.__locate_pos = current_pos
  end
  -- Skip the first preview call — it fires for pos 1 ("default") before
  -- the load event repositions the cursor via pos(N). Without this guard
  -- the default theme flashes for one frame.
  local settled = not current_pos
  opts.preview = shell.stringify_data(function(sel)
    if not settled then
      settled = true
      return
    end
    if not sel or not sel[1] then
      return
    end
    local theme = lookup[sel[1]]
    if not theme then
      return
    end
    previewed = true
    vim.opt.background = "dark"
    hook.exec(theme.before, "preview.before", vim.log.levels.DEBUG)
    pcall(vim.cmd.colorscheme, theme.colorscheme)
    hook.exec(theme.after, "preview.after", vim.log.levels.DEBUG)
  end, opts, "{}")

  -- Restore on close/cancel — re-run hooks so side effects are restored.
  opts.winopts = opts.winopts or {}
  opts.winopts.on_close = function()
    if previewed and current_cs then
      vim.o.background = current_bg
      if current_entry then
        hook.exec(current_entry.before, "restore.before", vim.log.levels.DEBUG)
      end
      pcall(vim.cmd.colorscheme, current_cs)
      if current_entry then
        hook.exec(current_entry.after, "restore.after", vim.log.levels.DEBUG)
      end
    end
  end

  opts._headers = { "actions" }
  opts.actions = {
    ["enter"] = {
      fn = function(selected)
        if not selected or not selected[1] then
          return
        end
        local theme = lookup[selected[1]]
        if theme then
          previewed = false -- skip restore
          store.apply(theme, true)
        end
      end,
      header = "save theme",
    },
    ["ctrl-s"] = {
      fn = function(selected)
        if not selected or not selected[1] then
          return
        end
        local theme = lookup[selected[1]]
        if theme then
          previewed = false -- skip restore
          store.apply(theme, false)
        end
      end,
      header = "session only",
    },
  }

  core.fzf_exec(items, opts)
end

return M
