local h = require("tests.helpers")
local MiniTest = require("mini.test")
local new_set = MiniTest.new_set

local T = new_set()
local ctx, child

T["notes"] = new_set({
  hooks = {
    pre_once = function() ctx = h.setup() end,
    pre_case = function()
      child = h.new_child(ctx)
      -- Set $NOTE to a temp dir inside the child process.
      child.lua([[
        _G._test_note_dir = vim.fn.tempname()
        vim.fn.mkdir(_G._test_note_dir, "p")
        vim.env.NOTE = _G._test_note_dir
      ]])
    end,
    post_case = function()
      child.lua([[vim.fn.delete(_G._test_note_dir, "rf")]])
      child.stop()
    end,
    post_once = function() h.teardown(ctx) end,
  },
})

-- ---------------------------------------------------------------------------
-- NoteToday creates diary file with header
-- ---------------------------------------------------------------------------

T["notes"]["NoteToday creates diary file"] = function()
  child.cmd("NoteToday")

  -- File should exist and contain the date header.
  local lines = child.lua_get("vim.api.nvim_buf_get_lines(0, 0, 5, false)")
  local date = os.date("%Y-%m-%d")
  local day_name = os.date("%A")
  local header = "# " .. date .. " - " .. day_name

  h.eq(lines[1], header)
  -- Second line is blank, third is the time header.
  h.eq(lines[2], "")
  h.eq(lines[3]:match("^## %d%d:%d%d$") ~= nil, true)
end

-- ---------------------------------------------------------------------------
-- NoteToday appends timestamp on second call
-- ---------------------------------------------------------------------------

T["notes"]["NoteToday appends timestamp on second call"] = function()
  child.cmd("NoteToday")
  -- Write the buffer so the file exists on disk.
  child.cmd("write")

  local count_before = child.lua_get([[
    #vim.tbl_filter(
      function(l) return l:match("^## %d%d:%d%d$") end,
      vim.api.nvim_buf_get_lines(0, 0, -1, false)
    )
  ]])
  h.eq(count_before, 1)

  -- Second call appends another timestamp.
  child.cmd("NoteToday")
  local count_after = child.lua_get([[
    #vim.tbl_filter(
      function(l) return l:match("^## %d%d:%d%d$") end,
      vim.api.nvim_buf_get_lines(0, 0, -1, false)
    )
  ]])
  h.eq(count_after, 2)
end

-- ---------------------------------------------------------------------------
-- NoteToday file path follows $NOTE/diary/YYYY/YYYY-MM-DD.md
-- ---------------------------------------------------------------------------

T["notes"]["NoteToday uses correct path"] = function()
  child.cmd("NoteToday")
  local bufname = child.lua_get("vim.api.nvim_buf_get_name(0)")
  local date = os.date("%Y-%m-%d")
  local year = os.date("%Y")
  local expected_suffix = "/diary/" .. year .. "/" .. date .. ".md"
  h.eq(bufname:sub(-#expected_suffix), expected_suffix)
end

return T
