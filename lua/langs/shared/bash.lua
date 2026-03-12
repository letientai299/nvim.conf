local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("bash", bufnr, {
    filetypes = { "bash", "sh", "zsh" },
    tools = {
      {
        name = "bash-language-server",
        bin = "bash-language-server",
        kind = "lsp",
      },
      { name = "shfmt", bin = "shfmt", kind = "fmt" },
    },
    lsp = "bashls",
    formatters = { "shfmt" },
    parsers = { "bash" },
  })
end

return M
