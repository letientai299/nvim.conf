local M = {}

--- Resolve the typescript library path from the project's node_modules.
--- Falls back to globally installed typescript.
--- @param root string project root directory
--- @return string|nil
local function get_tsdk(root)
  local project = root .. "/node_modules/typescript/lib"
  if vim.uv.fs_stat(project) then return project end
  local exe = vim.fn.exepath("tsc")
  if exe ~= "" then
    local real = vim.uv.fs_realpath(exe)
    if real then return real:match("(.*/typescript)/") .. "/lib" end
  end
  return nil
end

--- on_init callback that injects typescript.tsdk into init_options.
--- Use in any Volar-based LSP config (vue, astro, mdx).
function M.on_init(client)
  local tsdk = get_tsdk(client.root_dir)
  if tsdk then
    client.config.init_options = client.config.init_options or {}
    client.config.init_options.typescript = { tsdk = tsdk }
  end
end

return M
