local M = {}

function M.wait(bin, timeout_s)
  local interval_ms = 1000
  local elapsed = 0
  local timer = vim.uv.new_timer()
  timer:start(
    0,
    interval_ms,
    vim.schedule_wrap(function()
      elapsed = elapsed + 1
      if vim.fn.executable(bin) == 1 then
        timer:stop()
        timer:close()
        print("READY:" .. bin)
        vim.cmd("qa!")
      elseif elapsed >= timeout_s then
        timer:stop()
        timer:close()
        print("TIMEOUT:" .. bin)
        vim.cmd("cq")
      end
    end)
  )
end

return M
