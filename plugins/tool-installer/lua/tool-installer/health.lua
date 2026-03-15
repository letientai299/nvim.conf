local M = {}

function M.check()
  vim.health.start("tool-installer")

  -- Backend availability
  local backends = {
    { name = "mise", mod = "tool-installer.backend.mise" },
    { name = "brew", mod = "tool-installer.backend.brew" },
    { name = "script", mod = "tool-installer.backend.script" },
  }
  for _, b in ipairs(backends) do
    local backend = require(b.mod)
    if backend.available() then
      vim.health.ok(b.name .. " backend available")
    else
      vim.health.info(b.name .. " backend not found")
    end
  end

  -- Script dir
  local config = require("tool-installer").get_config()
  if config and config.script_dir and config.script_dir ~= "" then
    if vim.fn.isdirectory(config.script_dir) == 1 then
      vim.health.ok("script_dir: " .. config.script_dir)
    else
      vim.health.warn("script_dir does not exist: " .. config.script_dir)
    end
  end

  -- Catalog entries
  if config and config.catalog then
    local count = 0
    for name, tool in pairs(config.catalog) do
      count = count + 1
      if vim.fn.executable(tool.bin) == 1 then
        vim.health.ok(name .. " (" .. tool.bin .. ") installed")
      else
        vim.health.warn(name .. " (" .. tool.bin .. ") not found")
      end
    end
    vim.health.info(count .. " catalog entries")
  end

  -- Cache state
  local stats = require("tool-installer.cache").stats()
  vim.health.ok("Cache: " .. stats.count .. " entries at " .. stats.path)
end

return M
