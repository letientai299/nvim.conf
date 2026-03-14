-- Terminal management via toggleterm.nvim.
-- Prefix: <C-q>. Double-tap to toggle, <C-hjklf> to move, 1-9 to switch.

local lazy_require = require("lib.lazy_ondemand").lazy_require
local M = {}

-- Persistent layout state (survives toggle cycles).
M.direction = "horizontal"
M.wincmd = nil -- post-open wincmd for left/top edges

-- Direction table: key → { direction, wincmd|nil }
-- stylua: ignore
local layouts = {
  h = { "vertical",   "H" }, -- left
  j = { "horizontal", nil }, -- bottom (default)
  k = { "horizontal", "K" }, -- top
  l = { "vertical",   nil }, -- right
  f = { "float",      nil },
}

--- Build a tab label like "[1] [2*] [3]" for float titles.
--- The active terminal is marked with `*`.
local function tab_label(active_id)
  local terms = lazy_require("toggleterm.terminal").get_all()
  local parts = {}
  for _, t in ipairs(terms) do
    local label = "[" .. t.id .. (t.id == active_id and "*" or "") .. "]"
    table.insert(parts, label)
  end
  return table.concat(parts, " ")
end

local function set_float_title(term)
  if M.direction == "float" then
    term.display_name = tab_label(term.id)
  end
end

local function size(direction)
  if direction == "horizontal" then
    return 15
  end
  if direction == "vertical" then
    return 80
  end
end

--- Toggle the current terminal, applying any pending wincmd.
function M.toggle()
  local Terminal = lazy_require("toggleterm.terminal").Terminal
  local terms = lazy_require("toggleterm.terminal").get_all()

  -- Find the currently visible terminal, or fall back to term 1.
  local term
  for _, t in ipairs(terms) do
    if t:is_open() then
      term = t
      break
    end
  end
  if not term then
    term = Terminal:new({ id = 1, direction = M.direction })
  end

  -- If open, close. If closed, open with current layout.
  if term:is_open() then
    term:close()
    return
  end

  set_float_title(term)
  term:open(size(M.direction), M.direction)

  if M.wincmd then
    vim.cmd("wincmd " .. M.wincmd)
  end
end

--- Move terminal to a new edge/float layout.
function M.move(key)
  local layout = layouts[key]
  if not layout then
    return
  end

  M.direction = layout[1]
  M.wincmd = layout[2]

  -- Close any visible terminal, then reopen in the new layout.
  local terms = lazy_require("toggleterm.terminal").get_all()
  for _, t in ipairs(terms) do
    if t:is_open() then
      t:close()
      break
    end
  end

  -- Reopen with updated state.
  M.toggle()
end

--- Switch to terminal N (1-9). No-op if it doesn't exist.
function M.switch(n)
  local term = lazy_require("toggleterm.terminal").get(n)
  if not term then
    return
  end

  -- Close any currently visible terminal first.
  local terms = lazy_require("toggleterm.terminal").get_all()
  for _, t in ipairs(terms) do
    if t:is_open() then
      t:close()
      break
    end
  end

  set_float_title(term)
  term:open(size(M.direction), M.direction)
  if M.wincmd then
    vim.cmd("wincmd " .. M.wincmd)
  end
end

--- Create a new terminal with the next available ID.
function M.create()
  local terms = lazy_require("toggleterm.terminal").get_all()
  local max_id = 0
  for _, t in ipairs(terms) do
    if t.id > max_id then
      max_id = t.id
    end
  end

  local Terminal = lazy_require("toggleterm.terminal").Terminal
  local term = Terminal:new({ id = max_id + 1, direction = M.direction })

  -- Close any visible terminal first.
  for _, t in ipairs(terms) do
    if t:is_open() then
      t:close()
      break
    end
  end

  set_float_title(term)
  term:open(size(M.direction), M.direction)
  if M.wincmd then
    vim.cmd("wincmd " .. M.wincmd)
  end
end

--- Close terminal with confirmation if child processes are running.
function M.close()
  local terms = lazy_require("toggleterm.terminal").get_all()
  local term
  for _, t in ipairs(terms) do
    if t:is_open() then
      term = t
      break
    end
  end
  if not term then
    return
  end

  local pid = vim.fn.jobpid(term.job_id)
  local has_children = vim.fn.system("pgrep -P " .. pid)
  if has_children ~= "" then
    vim.ui.select({ "Yes", "No" }, {
      prompt = "Terminal has running processes. Close anyway?",
    }, function(choice)
      if choice == "Yes" then
        term:shutdown()
      end
    end)
  else
    term:shutdown()
  end
end

-- Build the lazy.nvim keys table.
local keys = {
  {
    "<C-q><C-q>",
    function()
      M.toggle()
    end,
    mode = { "n", "t" },
    desc = "Toggle terminal",
  },
  {
    "<C-q><C-x>",
    function()
      M.close()
    end,
    mode = { "n", "t" },
    desc = "Close terminal",
  },
  {
    "<C-q><C-n>",
    function()
      M.create()
    end,
    mode = { "n", "t" },
    desc = "Create terminal",
  },
}

-- stylua: ignore
local layout_descs = { h = "left", j = "bottom", k = "top", l = "right", f = "float" }
for key, _ in pairs(layouts) do
  table.insert(keys, {
    "<C-q><C-" .. key .. ">",
    function()
      M.move(key)
    end,
    mode = { "n", "t" },
    desc = "Terminal " .. layout_descs[key],
  })
end

for i = 1, 9 do
  table.insert(keys, {
    "<C-q>" .. i,
    function()
      M.switch(i)
    end,
    mode = { "n", "t" },
    desc = "Terminal " .. i,
  })
end

return {
  "akinsho/toggleterm.nvim",
  version = "*",
  keys = keys,
  opts = function()
    return {
      size = function(term)
        return size(term.direction)
      end,
      shade_terminals = false,
      float_opts = { border = "rounded", title_pos = "center" },
      winbar = {
        enabled = true,
        name_formatter = function(term)
          return "[" .. term.id .. "]"
        end,
      },
    }
  end,
}
