local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("bash", bufnr, {
    filetypes = { "bash", "sh", "zsh" },
    tools = {
      {
        bin = "bash-language-server",
        mise = "npm:bash-language-server",
        dependencies = { "node" },
      },
      { bin = "shfmt", mise = "shfmt" },
      { bin = "shellcheck", mise = "shellcheck" },
    },
    lsp = "bashls",
    formatters = { "shfmt" },
    linters = { "shellcheck" },
  })
end

return M
