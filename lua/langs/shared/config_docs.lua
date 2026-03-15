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
  require("langs.shared.entry").setup("yaml", bufnr, {
    tools = {
      {
        bin = "yaml-language-server",
        mise = "npm:yaml-language-server",
        dependencies = { "node" },
      },
      require("lib.prettier").tool(),
    },
    lsp = "yamlls",
    formatter_fts = { "yaml", "yaml.docker-compose" },
    formatters = { "prettier" },
  })
end

return M
