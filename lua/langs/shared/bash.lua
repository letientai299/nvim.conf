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
    },
    lsp = "bashls",
    formatters = { "shfmt" },
  })
end

return M
