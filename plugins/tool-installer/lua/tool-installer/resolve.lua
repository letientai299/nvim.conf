local M = {}

--- Flatten tools with their dependencies into a dependency-first ordered list.
--- Dependencies are resolved from the catalog by string key.
--- Deduplicates by bin name. Detects cycles.
---@param tools tool-installer.Tool[]
---@param catalog table<string, tool-installer.Tool>
---@return tool-installer.Tool[]
function M.flatten(tools, catalog)
  local visited = {} ---@type table<string, true>
  local in_stack = {} ---@type table<string, true>
  local result = {} ---@type tool-installer.Tool[]

  ---@param tool tool-installer.Tool
  ---@param path string[] for cycle error messages
  local function visit(tool, path)
    if visited[tool.bin] then
      return
    end
    if in_stack[tool.bin] then
      vim.notify(
        "[tool-installer] Dependency cycle: "
          .. table.concat(path, " → ")
          .. " → "
          .. tool.bin,
        vim.log.levels.ERROR
      )
      return
    end

    in_stack[tool.bin] = true
    path[#path + 1] = tool.bin

    if tool.dependencies then
      for _, dep_name in ipairs(tool.dependencies) do
        local dep = catalog[dep_name]
        if dep then
          visit(dep, path)
        else
          vim.notify(
            "[tool-installer] Unknown dependency: " .. dep_name,
            vim.log.levels.ERROR
          )
        end
      end
    end

    path[#path] = nil
    in_stack[tool.bin] = nil
    visited[tool.bin] = true
    result[#result + 1] = tool
  end

  for _, tool in ipairs(tools) do
    visit(tool, {})
  end

  return result
end

return M
