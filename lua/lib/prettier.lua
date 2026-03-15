local M = {}

--- Prettier config file names for project detection.
--- Does not include package.json (needs content inspection) — prettier's own
--- config discovery handles that case when cwd points to the project root.
--- @type FallbackSpec
M.fallback_spec = {
  names = {
    ".prettierrc",
    ".prettierrc.json",
    ".prettierrc.yml",
    ".prettierrc.yaml",
    ".prettierrc.json5",
    ".prettierrc.js",
    ".prettierrc.cjs",
    ".prettierrc.mjs",
    ".prettierrc.ts",
    ".prettierrc.toml",
    "prettier.config.js",
    "prettier.config.cjs",
    "prettier.config.mjs",
    "prettier.config.ts",
  },
  flag = "--config",
  fallback = vim.fn.stdpath("config") .. "/configs/.prettierrc",
}

--- @return lib.tools.Tool
function M.tool()
  return { bin = "prettier", kind = "fmt", mise = "npm:prettier" }
end

--- Build a conform.nvim spec that maps filetypes to prettier.
--- @param fts string|string[]
--- @return table lazy.nvim plugin spec
function M.conform(fts)
  if type(fts) == "string" then
    fts = { fts }
  end
  local by_ft = {}
  for _, ft in ipairs(fts) do
    by_ft[ft] = { "prettier" }
  end
  return {
    "stevearc/conform.nvim",
    opts = { formatters_by_ft = by_ft },
  }
end

return M
