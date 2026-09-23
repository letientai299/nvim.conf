local M = {}

function M.load()
  local result = vim
    .system({
      vim.env.SHELL or "/bin/sh",
      "-lic",
      "printf '\\0'; /usr/bin/env -0",
    }, { text = false })
    :wait(10000)

  local start = (result.stdout or ""):find("\0", 1, true)
  if result.code ~= 0 or not start then
    vim.notify("Shell environment import failed", vim.log.levels.WARN)
    return false
  end

  -- Skip shell startup banners.
  for entry in result.stdout:sub(start + 1):gmatch("([^%z]+)") do
    local name, value = entry:match("^([^=]+)=(.*)$")
    if name then
      vim.env[name] = value
    end
  end
  return true
end

return M
