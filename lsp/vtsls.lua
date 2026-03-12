local function resolve_pkg(bin, pkg)
  local exe = vim.fn.exepath(bin)
  if exe == "" then
    return nil
  end
  local real = vim.uv.fs_realpath(exe)
  if not real then
    return nil
  end
  local target = "node_modules/" .. pkg
  local i = real:find(target, 1, true)
  if not i then
    return nil
  end
  return real:sub(1, i + #target - 1)
end

local filetypes =
  { "javascript", "javascriptreact", "typescript", "typescriptreact" }
local plugins = {}

local vue_path = resolve_pkg("vue-language-server", "@vue/language-server")
if vue_path then
  table.insert(plugins, {
    name = "@vue/typescript-plugin",
    location = vue_path,
    languages = { "vue" },
    configNamespace = "typescript",
  })
  filetypes[#filetypes + 1] = "vue"
end

local svelte_path = resolve_pkg("svelteserver", "svelte-language-server")
if svelte_path then
  table.insert(plugins, {
    name = "typescript-svelte-plugin",
    location = svelte_path .. "/node_modules/typescript-svelte-plugin",
    enableForWorkspaceTypeScriptVersions = true,
  })
end

local config = {
  cmd = { "vtsls", "--stdio" },
  filetypes = filetypes,
  root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
  settings = {
    typescript = { tsdk = require("lib.volar").get_tsdk() },
  },
}

if #plugins > 0 then
  config.settings.vtsls = {
    tsserver = {
      globalPlugins = plugins,
    },
  }
end

return config
