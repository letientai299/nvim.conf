local M = {}

function M.toml(bufnr)
  require("langs.shared.entry").setup("toml", bufnr, {
    tools = {
      { bin = "taplo", mise = "taplo" },
    },
    lsp = "taplo",
    formatters = { "taplo" },
  })
end

function M.yaml(bufnr)
  local tools = {
    {
      bin = "yaml-language-server",
      mise = "npm:yaml-language-server",
      dependencies = { "node" },
    },
    require("lib.prettier").tool(),
  }
  if bufnr and require("lib.github_actions").root(bufnr) then
    tools[#tools + 1] = { bin = "actionlint", mise = "actionlint" }
  end
  require("langs.shared.entry").setup("yaml", bufnr, {
    tools = tools,
    lsp = "yamlls",
    linters = { "actionlint" },
    formatter_fts = { "yaml", "yaml.docker-compose" },
    formatters = { "prettier" },
  })
end

return M
