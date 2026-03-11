local h = require("tests.helpers")
local MiniTest = require("mini.test")
local new_set = MiniTest.new_set

local T = new_set()
local ctx, child

T["keymaps"] = new_set({
  hooks = {
    pre_once = function() ctx = h.setup() end,
    pre_case = function() child = h.new_child(ctx) end,
    post_case = function() child.stop() end,
    post_once = function() h.teardown(ctx) end,
  },
})

-- ---------------------------------------------------------------------------
-- BufOnly
-- ---------------------------------------------------------------------------

T["keymaps"]["BufOnly closes other buffers"] = function()
  -- Open 3 buffers.
  child.cmd("edit " .. h.root .. "/init.lua")
  child.cmd("edit " .. h.root .. "/Makefile")
  child.cmd("edit " .. h.root .. "/lua/options.lua")

  local before = child.lua_get([[#vim.tbl_filter(
    function(b) return vim.bo[b].buflisted end,
    vim.api.nvim_list_bufs()
  )]])
  h.eq(before >= 3, true)

  child.cmd("BufOnly")

  local after = child.lua_get([[#vim.tbl_filter(
    function(b) return vim.bo[b].buflisted end,
    vim.api.nvim_list_bufs()
  )]])
  h.eq(after, 1)
end

return T
