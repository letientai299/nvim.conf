local prettier = require("lib.prettier")
local fts = { "javascript", "javascriptreact", "typescript", "typescriptreact" }

require("lib.tools").check(fts, {
  { name = "vtsls", bin = "vtsls", kind = "lsp" },
  prettier.tool(),
  { name = "biome", bin = "biome", kind = "lint" },
})

--- Resolve the npm package directory from a binary on PATH.
--- Follows: exepath → realpath → walk up to find node_modules/<pkg>.
--- @param bin string executable name
--- @param pkg string npm package name (e.g. "@vue/language-server")
--- @return string|nil
local function resolve_pkg(bin, pkg)
  local exe = vim.fn.exepath(bin)
  if exe == "" then return nil end
  local real = vim.uv.fs_realpath(exe)
  if not real then return nil end
  local target = "node_modules/" .. pkg
  local i = real:find(target, 1, true)
  if not i then return nil end
  return real:sub(1, i + #target - 1)
end

-- Detect framework TS plugins and wire them into vtsls
local plugins = {}

local vue_path = resolve_pkg("vue-language-server", "@vue/language-server")
if vue_path then
  table.insert(plugins, {
    name = "@vue/typescript-plugin",
    location = vue_path,
    languages = { "vue" },
    configNamespace = "typescript",
  })
end

local svelte_path = resolve_pkg("svelteserver", "svelte-language-server")
if svelte_path then
  table.insert(plugins, {
    name = "typescript-svelte-plugin",
    location = svelte_path .. "/node_modules/typescript-svelte-plugin",
    enableForWorkspaceTypeScriptVersions = true,
  })
end

if #plugins > 0 then
  vim.lsp.config("vtsls", {
    settings = {
      vtsls = {
        tsserver = {
          globalPlugins = plugins,
        },
      },
    },
    filetypes = vue_path
        and { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue" }
      or nil,
  })
end

require("lib.lsp").enable("vtsls")

local linters = { "biomejs" }

return {
  prettier.conform(fts),
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        javascript = linters,
        javascriptreact = linters,
        typescript = linters,
        typescriptreact = linters,
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "javascript", "typescript", "tsx", "jsdoc" } },
  },
}
