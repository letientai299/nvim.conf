local M = {}

--- CSharpier config file names for project detection.
--- CSharpier also supports .editorconfig, so avoid injecting the fallback when
--- a project-level editorconfig already exists.
--- @type FallbackSpec
M.fallback_spec = {
  names = {
    ".csharpierrc",
    ".csharpierrc.json",
    ".csharpierrc.yaml",
    ".csharpierrc.yml",
    ".editorconfig",
  },
  flag = "--config-path",
  fallback = vim.fn.stdpath("config") .. "/configs/csharpierrc.yml",
}

--- @return tool-installer.Tool
function M.tool()
  return {
    bin = "csharpier",
    mise = "dotnet:csharpier",
    dependencies = { "dotnet" },
  }
end

return M
