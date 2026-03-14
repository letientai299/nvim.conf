local M = {}

--- @return lib.tools.Tool
function M.tool()
  return { bin = "biome", kind = "lint", mise = "biome" }
end

return M
