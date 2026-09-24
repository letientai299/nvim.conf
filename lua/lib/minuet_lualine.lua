local M = require("lualine.component"):extend()

function M:init(options)
  M.super.init(self, options)
  require("lib.lazy_ondemand").on_load("minuet-ai.nvim", function()
    self.component = require("minuet.lualine"):new(options)
  end)
end

function M:update_status()
  if self.component then
    return self.component:update_status()
  end
  return ""
end

return M
