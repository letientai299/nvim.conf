local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("racket", bufnr, {
    tools = {
      { name = "racket-langserver", bin = "racket", kind = "lsp" },
      { name = "raco fmt", bin = "raco", kind = "fmt" },
    },
    lsp = "racket_langserver",
    formatter_defs = {
      raco_fmt = {
        command = "raco",
        args = { "fmt" },
        stdin = true,
      },
    },
    formatters = { "raco_fmt" },
  })
end

return M
