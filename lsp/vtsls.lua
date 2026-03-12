--- Resolve the global TypeScript SDK lib path via Node's require.resolve.
--- Works with any package manager (npm, pnpm, mise, etc.).
--- vtsls requires typescript.tsdk to initialize; without it the server crashes
--- with "Request initialize failed: typescript.tsdk init option is required".
local function resolve_tsdk()
  -- NODE_PATH includes the global prefix so require.resolve finds globally-installed typescript too
  local cmd = 'NODE_PATH="$(npm root -g 2>/dev/null)" node -e "console.log(require.resolve(\'typescript/lib/typescript.js\'))"'
  local out = vim.fn.system(cmd)
  local path = vim.trim(out)
  if vim.v.shell_error ~= 0 or path == "" then return nil end
  return vim.fs.dirname(path)
end

return {
  cmd = { "vtsls", "--stdio" },
  filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
  root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
  settings = {
    typescript = { tsdk = resolve_tsdk() },
  },
}
