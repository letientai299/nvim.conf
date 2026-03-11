-- Install plugins into .tests/data/ for test caching.
-- Run: nvim --headless -u tests/init.lua -c "luafile tests/install.lua" -c quitall

local h = require("tests.helpers")
local ctx = h.setup()
local child = h.new_child(ctx)

child.lua([[
  local lazy = require("lazy")
  lazy.install({ show = false })
  vim.wait(60000, function()
    for _, p in ipairs(lazy.plugins()) do
      if not p._.installed then return false end
    end
    return true
  end, 200)
]])

child.stop()
h.teardown(ctx)
