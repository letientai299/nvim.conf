local h = require("tests.helpers")
local MiniTest = require("mini.test")
local new_set = MiniTest.new_set

local T = new_set()
local ctx, child

T["startup"] = new_set({
  hooks = {
    pre_once = function() ctx = h.setup() end,
    pre_case = function() child = h.new_child(ctx) end,
    post_case = function() child.stop() end,
    post_once = function() h.teardown(ctx) end,
  },
})

T["startup"]["no errors on load"] = function()
  h.eq(child.lua_get("vim.v.errmsg"), "")
end

T["startup"]["netrw is disabled"] = new_set({
  parametrize = {
    { "loaded_netrw", 1 },
    { "loaded_netrwPlugin", 1 },
  },
})

T["startup"]["netrw is disabled"]["g:%s == %s"] = function(var, val)
  h.eq(child.lua_get("vim.g." .. var), val)
end

T["startup"]["lazy.nvim is available"] = function()
  h.eq(child.lua_get("pcall(require, 'lazy')"), true)
end

T["startup"]["expected plugins loaded"] = new_set({
  parametrize = {
    { "oil.nvim" },
    { "lazy.nvim" },
  },
})

T["startup"]["expected plugins loaded"]["%s"] = function(name)
  h.eq(
    child.lua_get(string.format([[require("lazy.core.config").plugins[%q] ~= nil]], name)),
    true
  )
end

T["startup"]["dirsv.nvim registered but lazy"] = function()
  h.eq(
    child.lua_get([[(function()
      local p = require("lazy.core.config").plugins["dirsv.nvim"]
      return p ~= nil and (p._.loaded == nil)
    end)()]]),
    true
  )
end

return T
