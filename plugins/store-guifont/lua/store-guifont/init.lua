--- Per-context GUI font persistence and picker.
local M = {}

local state_dir = vim.fn.stdpath("state") .. "/store"

--- Read a JSON state file, returning an empty table on any failure.
---@param path string
---@return table
local function read_json(path)
  local f = io.open(path, "r")
  if not f then
    return {}
  end
  local ok, data = pcall(vim.json.decode, f:read("*a"))
  f:close()
  return ok and data or {}
end

--- Write a table as JSON to `path`, creating parent dirs as needed.
---@param path string
---@param tbl table
local function write_json(path, tbl)
  vim.fn.mkdir(state_dir, "p")
  local f = io.open(path, "w")
  if not f then
    return
  end
  f:write(vim.json.encode(tbl))
  f:close()
end

--- Migrate a key from the old state location to a new file.
--- Removes the old file when no other keys remain.
---@param name string  context name (e.g. "neovide")
---@param new_path string
---@param key string  key to migrate (e.g. "guifont")
local function migrate_key(name, new_path, key)
  local cur = read_json(new_path)
  if cur[key] ~= nil then
    return
  end
  local old_path = vim.fn.stdpath("state") .. "/" .. name .. ".json"
  local old = read_json(old_path)
  if not old[key] then
    return
  end
  cur[key] = old[key]
  write_json(new_path, cur)
  old[key] = nil
  if next(old) == nil then
    os.remove(old_path)
  else
    write_json(old_path, old)
  end
end

--- Create a font context for a GUI host.
---@param name string  context name (e.g. "neovide", "firenvim")
---@return table ctx   context object with apply/save/pick/map_pick/map_zoom
function M.new(name)
  local path = state_dir .. "/" .. name .. "-guifont.json"
  migrate_key(name, path, "guifont")

  local ctx = {}

  --- Load saved guifont or apply `default_font`.
  ---@param default_font string
  function ctx:apply(default_font)
    local saved = read_json(path).guifont
    vim.o.guifont = saved or default_font
  end

  --- Persist current `vim.o.guifont` to disk (merge-write).
  function ctx:save()
    local data = read_json(path)
    data.guifont = vim.o.guifont
    write_json(path, data)
  end

  --- Load scale factor from JSON, set `vim.g[opts.var]`, auto-persist on exit.
  ---@param opts { var: string, default: number }
  function ctx:apply_scale(opts)
    local saved = read_json(path).scale_factor
    vim.g[opts.var] = saved or opts.default
    self._scale_var = opts.var

    vim.api.nvim_create_autocmd("VimLeavePre", {
      callback = function()
        local data = read_json(path)
        data.scale_factor = vim.g[opts.var]
        write_json(path, data)
      end,
    })
  end

  --- Bind zoom in/out keymaps that multiply/divide `vim.g[ctx._scale_var]`.
  ---@param opts? { factor?: number, zoom_in?: string, zoom_out?: string }
  function ctx:map_scale_zoom(opts)
    opts = opts or {}
    local factor = opts.factor or 1.1
    local key_in = opts.zoom_in or "<D-=>"
    local key_out = opts.zoom_out or "<D-->"
    local var = self._scale_var

    vim.keymap.set("n", key_in, function()
      vim.g[var] = vim.g[var] * factor
    end, { desc = "Zoom in (scale)" })
    vim.keymap.set("n", key_out, function()
      vim.g[var] = vim.g[var] / factor
    end, { desc = "Zoom out (scale)" })
  end

  --- Open an fzf-lua monospace font picker with live preview.
  function ctx:pick()
    local fzf = require("fzf-lua")
    local prev_font = vim.o.guifont

    fzf.fzf_exec("fc-list ':spacing=100' family | sort -u", {
      prompt = "Font> ",
      fzf_opts = { ["--preview-window"] = "hidden" },
      actions = {
        ["default"] = function(selected)
          if not selected or #selected == 0 then
            return
          end
          -- Preserve all attributes (style, size, etc.) from the current font.
          local suffix = prev_font:match("(:.+)$") or ":h15"
          vim.o.guifont = selected[1] .. suffix
          self:save()
        end,
        ["esc"] = function()
          vim.o.guifont = prev_font
        end,
      },
    })
  end

  --- Bind `<Leader>fp` (or custom lhs) to the font picker.
  ---@param lhs? string  keymap lhs, defaults to `<Leader>fp`
  function ctx:map_pick(lhs)
    vim.keymap.set("n", lhs or "<Leader>fp", function()
      self:pick()
    end, { desc = "Pick font" })
  end

  --- Bind zoom in/out keymaps that scale the `:hNN` portion of guifont.
  ---@param opts? { factor?: number, zoom_in?: string, zoom_out?: string }
  function ctx:map_zoom(opts)
    opts = opts or {}
    local factor = opts.factor or 1.1
    local key_in = opts.zoom_in or "<D-=>"
    local key_out = opts.zoom_out or "<D-->"

    local function zoom(mult)
      local font = vim.o.guifont
      local new = font:gsub(":h(%d+%.?%d*)", function(size)
        return ":h" .. math.max(1, math.floor(tonumber(size) * mult + 0.5))
      end)
      vim.o.guifont = new
      self:save()
    end

    vim.keymap.set("n", key_in, function()
      zoom(factor)
    end, { desc = "Zoom in" })
    vim.keymap.set("n", key_out, function()
      zoom(1 / factor)
    end, { desc = "Zoom out" })
  end

  return ctx
end

return M
