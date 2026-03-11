local h = require("tests.helpers")
local MiniTest = require("mini.test")
local new_set = MiniTest.new_set

local T = new_set()
local ctx, child

T["oil"] = new_set({
  hooks = {
    pre_once = function() ctx = h.setup() end,
    pre_case = function() child = h.new_child(ctx) end,
    post_case = function() child.stop() end,
    post_once = function() h.teardown(ctx) end,
  },
})

--- Helper: open oil in the child and wait for it.
local function open_oil()
  child.cmd("edit " .. h.root .. "/init.lua")
  child.type_keys([[<C-\>]])
  vim.wait(50)
  child.lua("vim.wait(2000, function() return vim.bo.filetype == 'oil' end)")
end

-- ---------------------------------------------------------------------------
-- Keymaps registered
-- ---------------------------------------------------------------------------

T["oil"]["global keymaps registered"] = new_set({
  parametrize = {
    { "<C-Bslash>" },
    { "<M-Bslash>" },
  },
})

T["oil"]["global keymaps registered"]["%s"] = function(lhs)
  h.eq(
    child.lua_get(string.format([[(function()
      for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
        if m.lhs == %q then return true end
      end
      return false
    end)()]], lhs)),
    true
  )
end

-- ---------------------------------------------------------------------------
-- Open oil via keymap
-- ---------------------------------------------------------------------------

T["oil"]["<C-\\> opens oil buffer"] = function()
  open_oil()
  h.eq(child.lua_get("vim.bo.filetype"), "oil")
end

-- ---------------------------------------------------------------------------
-- Navigate entries with j and Enter
-- ---------------------------------------------------------------------------

T["oil"]["j and Enter navigates"] = function()
  open_oil()
  local before = child.lua_get("vim.api.nvim_buf_get_name(0)")
  child.type_keys("j", "<CR>")
  vim.wait(50)
  child.lua("vim.wait(2000, function() return vim.api.nvim_buf_get_name(0) ~= '' end)")
  local after = child.lua_get("vim.api.nvim_buf_get_name(0)")
  if before == after then
    error("expected buffer name to change after j<CR>")
  end
end

-- ---------------------------------------------------------------------------
-- Config options (table-driven)
-- ---------------------------------------------------------------------------

T["oil"]["config options"] = new_set({
  parametrize = {
    { "view_options.show_hidden", true },
    { "skip_confirm_for_simple_edits", true },
  },
})

T["oil"]["config options"]["%s == %s"] = function(path, expected)
  open_oil()
  h.eq(child.lua_get('require("oil.config").' .. path), expected)
end

-- ---------------------------------------------------------------------------
-- Search register save/restore
-- ---------------------------------------------------------------------------

T["oil"]["saves and restores search register"] = function()
  child.cmd("edit " .. h.root .. "/init.lua")
  child.lua([[vim.fn.setreg("/", "original_search")]])

  child.type_keys([[<C-\>]])
  vim.wait(50)
  child.lua("vim.wait(2000, function() return vim.bo.filetype == 'oil' end)")

  local during = child.lua_get([[vim.fn.getreg("/")]])
  if during == "original_search" then
    error("expected search register to change when opening oil")
  end

  -- Leave oil by editing a different buffer (triggers BufLeave).
  child.cmd("edit " .. h.root .. "/init.lua")
  vim.wait(50)
  child.lua("vim.wait(1000, function() return vim.bo.filetype ~= 'oil' end)")
  h.eq(child.lua_get([[vim.fn.getreg("/")]]), "original_search")
end

-- ---------------------------------------------------------------------------
-- Oil-local buffer keymaps (table-driven)
-- ---------------------------------------------------------------------------

T["oil"]["buffer keymaps exist"] = new_set({
  parametrize = {
    { "yp" },
    { "gd" },
  },
})

T["oil"]["buffer keymaps exist"]["%s"] = function(lhs)
  open_oil()
  h.eq(
    child.lua_get(string.format([[(function()
      for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
        if m.lhs == %q then return true end
      end
      return false
    end)()]], lhs)),
    true
  )
end

-- ---------------------------------------------------------------------------
-- Toggle detail columns
-- ---------------------------------------------------------------------------

T["oil"]["gd toggles detail columns"] = function()
  open_oil()
  local before = child.lua_get([[#(require("oil").get_columns and require("oil").get_columns() or {})]])
  child.type_keys("gd")
  vim.wait(50)
  local after = child.lua_get([[#(require("oil").get_columns and require("oil").get_columns() or {})]])
  if after <= before then
    error(string.format("expected columns to increase: before=%d after=%d", before, after))
  end
end

-- ---------------------------------------------------------------------------
-- BufLeave autocmd
-- ---------------------------------------------------------------------------

T["oil"]["BufLeave autocmd registered"] = function()
  h.eq(
    child.lua_get([[(function()
      local cmds = vim.api.nvim_get_autocmds({ event = "BufLeave", pattern = "oil://*" })
      return #cmds > 0
    end)()]]),
    true
  )
end

return T
