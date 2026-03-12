local M = {}

function M.toml(bufnr)
  require("langs.shared.entry").setup("toml", bufnr, {
    tools = {
      { name = "taplo", bin = "taplo", kind = "lsp/fmt" },
    },
    lsp = "taplo",
    formatters = { "taplo" },
    parsers = { "toml" },
  })
end

function M.yaml(bufnr)
  require("langs.shared.entry").setup("yaml", bufnr, {
    tools = {
      {
        name = "yaml-language-server",
        bin = "yaml-language-server",
        kind = "lsp",
      },
      require("lib.prettier").tool(),
    },
    lsp = "yamlls",
    formatter_fts = { "yaml", "yaml.docker-compose" },
    formatters = { "prettier" },
    parsers = { "yaml" },
  })
end

return M
