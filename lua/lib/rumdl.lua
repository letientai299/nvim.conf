local M = {}

--- @type FallbackSpec
M.fallback_spec = {
  names = { ".rumdl.toml", "rumdl.toml" },
  flag = "--config",
  fallback = vim.fn.stdpath("config") .. "/configs/rumdl.toml",
  extra_dirs = { ".config" },
}

--- @return tool-installer.Tool
function M.tool()
  return { bin = "rumdl", mise = "rumdl" }
end

return M
