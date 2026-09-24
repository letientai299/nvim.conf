local M = {}

function M.setup()
  local component = require("lualine.components.buffers")

  -- Deleted buffer IDs accumulate in long sessions.
  function component:buffers()
    local buffers = {}
    component.bufpos2nr = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buf].buflisted and vim.bo[buf].buftype ~= "quickfix" then
        buffers[#buffers + 1] = self:new_buffer(buf, #buffers + 1)
        component.bufpos2nr[#buffers] = buf
      end
    end
    return buffers
  end
end

return M
