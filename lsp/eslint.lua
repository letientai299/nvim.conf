local fts = {
  "javascript",
  "javascriptreact",
  "typescript",
  "typescriptreact",
  "vue",
  "svelte",
  "astro",
  "graphql",
}

local root_markers = {
  "eslint.config.js",
  "eslint.config.mjs",
  "eslint.config.cjs",
  "eslint.config.ts",
  "eslint.config.mts",
  "eslint.config.cts",
  ".eslintrc",
  ".eslintrc.js",
  ".eslintrc.cjs",
  ".eslintrc.yaml",
  ".eslintrc.yml",
  ".eslintrc.json",
}

--- The ESLint LSP sends workspace/configuration requests that must return
--- a computed workingDirectory per buffer. Without this handler the server
--- receives undefined and crashes with "path must be of type string".
--- See https://github.com/esmuellert/nvim-eslint
local function on_init(client)
  client.handlers["workspace/configuration"] = function(_, params, ctx)
    local results = {}
    for _, item in ipairs(params.items) do
      if item.section == "eslint" then
        local uri = item.scopeUri
        local bufnr = uri and vim.uri_to_bufnr(uri)
        local bufpath = bufnr and vim.api.nvim_buf_get_name(bufnr)
        local dir = bufpath and bufpath ~= "" and vim.fs.root(bufnr, { "package.json", ".git" })
          or vim.uv.cwd()
        local settings = vim.deepcopy(client.settings.eslint or client.settings or {})
        settings.workingDirectory = { directory = dir }
        table.insert(results, settings)
      else
        table.insert(results, vim.NIL)
      end
    end
    return results
  end
end

return {
  cmd = { "vscode-eslint-language-server", "--stdio" },
  filetypes = fts,
  root_markers = root_markers,
  on_init = on_init,
  settings = {
    eslint = {
      validate = "on",
      rulesCustomizations = {},
      run = "onType",
      codeAction = {
        disableRuleComment = { enable = true, location = "separateLine" },
        showDocumentation = { enable = true },
      },
      codeActionOnSave = { mode = "all" },
    },
  },
}
