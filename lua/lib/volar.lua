local M = {}

--- Resolve the TypeScript SDK lib path. Checks project node_modules first,
--- then falls back to Node's require.resolve (works with any package manager).
--- @param root string|nil project root directory (defaults to cwd)
--- @return string|nil
function M.get_tsdk(root)
  if not root then
    root = vim.uv.cwd()
  end
  local project = root .. "/node_modules/typescript/lib"
  if vim.uv.fs_stat(project) then
    return project
  end
  local cmd =
    'NODE_PATH="$(npm root -g 2>/dev/null)" node -e "console.log(require.resolve(\'typescript/lib/typescript.js\'))"'
  local out = vim.fn.system(cmd)
  local path = vim.trim(out)
  if vim.v.shell_error == 0 and path ~= "" then
    return vim.fs.dirname(path)
  end
  return nil
end

return M
