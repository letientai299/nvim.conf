local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("bash", bufnr, {
    filetypes = { "bash", "sh", "zsh" },
    tools = {
      {
        bin = "bash-language-server",
        kind = "lsp",
        mise = "npm:bash-language-server",
      },
      { bin = "shfmt", kind = "fmt", mise = "shfmt" },
      { bin = "shellcheck", kind = "lint", mise = "shellcheck" },
    },
    lsp = "bashls",
    formatters = { "shfmt" },
    linters = { "shellcheck" },
  })
end

return M
