--- Shared GUI font persistence and picker for Neovide / Firenvim.
local M = {}

--- Create a state store backed by a JSON file in stdpath("state").
---@param name string  filename without extension (e.g. "neovide", "firenvim")
---@return { load: fun(): table, save: fun(patch: table) }
function M.state(name)
  local path = vim.fn.stdpath("state") .. "/" .. name .. ".json"

  local function load()
    local f = io.open(path, "r")
    if not f then
      return {}
    end
    local ok, data = pcall(vim.json.decode, f:read("*a"))
    f:close()
    return ok and data or {}
  end

  local function save(patch)
    local cur = load()
    for k, v in pairs(patch) do
      cur[k] = v
    end
    local f = io.open(path, "w")
    if not f then
      return
    end
    f:write(vim.json.encode(cur))
    f:close()
  end

  return { load = load, save = save }
end

--- Apply persisted guifont or fall back to `default_font`.
---@param store { load: fun(): table, save: fun(patch: table) }
---@param default_font string
function M.apply(store, default_font)
  local saved = store.load().guifont
  vim.o.guifont = saved or default_font
end

--- Map `<Leader>fp` to a fzf-lua monospace font picker that persists the choice.
---@param store { load: fun(): table, save: fun(patch: table) }
function M.map_picker(store)
  vim.keymap.set("n", "<Leader>fp", function()
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
          local font = selected[1] .. ":h15"
          vim.o.guifont = font
          store.save({ guifont = font })
        end,
        ["esc"] = function()
          vim.o.guifont = prev_font
        end,
      },
    })
  end, { desc = "Pick font" })
end

--- Map `<D-=>` / `<D-->` to zoom in/out by scaling the :hNN portion of guifont.
---@param store { load: fun(): table, save: fun(patch: table) }
function M.map_zoom(store)
  local function zoom(factor)
    local font = vim.o.guifont
    local new = font:gsub(":h(%d+%.?%d*)", function(size)
      return ":h" .. math.max(1, math.floor(tonumber(size) * factor + 0.5))
    end)
    vim.o.guifont = new
    store.save({ guifont = new })
  end

  vim.keymap.set("n", "<D-=>", function() zoom(1.1) end, { desc = "Zoom in" })
  vim.keymap.set("n", "<D-->", function() zoom(1 / 1.1) end, { desc = "Zoom out" })
end

return M
