local M = {}

local path = vim.fn.stdpath("state") .. "/store/fzf-ui.json"
local positions = { up = true, right = true, down = true, left = true }

local function read_state()
  local file = io.open(path, "r")
  if not file then
    return {}
  end
  local ok, data = pcall(vim.json.decode, file:read("*a"))
  file:close()
  if not ok or type(data) ~= "table" then
    return {}
  end
  local state = {}
  for _, key in ipairs({ "fullscreen", "hidden", "wrap" }) do
    if type(data[key]) == "boolean" then
      state[key] = data[key]
    end
  end
  if type(data.position) == "string" and positions[data.position] then
    state.position = data.position .. ":50%"
  elseif type(data.position) == "string" then
    local position, size = data.position:match("^(%a+):(%d+%%?)$")
    local amount = size and tonumber((size:gsub("%%", "")))
    if
      positions[position]
      and amount
      and amount > 0
      and (not size:find("%%") or amount <= 100)
    then
      state.position = data.position
    end
  end
  return state
end

local function snapshot(win)
  local state = { fullscreen = not not win.fullscreen }
  if win.previewer_is_builtin then
    state.hidden = win.preview_hidden
    state.wrap = win.preview_wrap
    state.position = win:normalize_preview_layout().str
  end
  return state
end

local function track_window()
  local win = require("fzf-lua.win").__SELF()
  if not win or win.winopts.split or win._o._is_fzf_tmux then
    return
  end
  if win.on_closes.fzf_ui then
    return
  end
  local initial = snapshot(win)
  win.on_closes.fzf_ui = function()
    local changes = {}
    for key, value in pairs(snapshot(win)) do
      if value ~= initial[key] then
        changes[key] = value
      end
    end
    if not next(changes) then
      return
    end
    local state = vim.tbl_extend("force", read_state(), changes)
    local temporary = path .. "." .. vim.fn.getpid() .. ".tmp"
    local ok, err = pcall(function()
      vim.fn.mkdir(vim.fs.dirname(path), "p")
      vim.fn.writefile({ vim.json.encode(state) }, temporary)
      local renamed, reason = vim.uv.fs_rename(temporary, path)
      assert(renamed, reason)
    end)
    if not ok then
      os.remove(temporary)
      vim.notify("Fzf UI save failed: " .. tostring(err), vim.log.levels.WARN)
    end
  end
end

function M.winopts()
  local state = read_state()
  local preview = {
    layout = "vertical",
    vertical = "up:50%",
    hidden = state.hidden,
    wrap = state.wrap,
  }
  if state.position then
    local position = state.position:match("^%a+")
    local vertical = position == "up" or position == "down"
    preview.layout = vertical and "vertical" or "horizontal"
    preview[preview.layout] = state.position
  end
  return {
    fullscreen = state.fullscreen,
    preview = preview,
    on_create = track_window,
  }
end

return M
