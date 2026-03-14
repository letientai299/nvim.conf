local M = {}

function M.assert(timeout_s)
  local interval_ms = 1000
  local elapsed = 0
  local timer = vim.uv.new_timer()
  timer:start(
    5000,
    interval_ms,
    vim.schedule_wrap(function()
      elapsed = elapsed + 1
      local clients = vim.lsp.get_clients({ bufnr = 0 })
      if #clients > 0 then
        timer:stop()
        timer:close()
        for _, c in ipairs(clients) do
          print("LSP:" .. c.name)
        end
        vim.cmd("qa!")
      elseif elapsed >= timeout_s then
        timer:stop()
        timer:close()
        print("TIMEOUT:lsp")
        vim.cmd("cq")
      end
    end)
  )
end

return M
