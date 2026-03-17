local M = {}

--- StyLua config file names for project detection.
--- StyLua also respects .editorconfig when no stylua config is present, so
--- avoid injecting the fallback when a project-level editorconfig exists.
--- @type FallbackSpec
M.fallback_spec = {
  names = {
    ".stylua.toml",
    "stylua.toml",
    ".editorconfig",
  },
  flag = "--config-path",
  fallback = vim.fn.stdpath("config") .. "/configs/stylua.toml",
}

--- @return tool-installer.Tool
function M.tool()
  return { bin = "stylua", mise = "stylua" }
end

return M
