local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("dockerfile", bufnr, {
    tools = {
      { name = "docker-langserver", bin = "docker-langserver", kind = "lsp" },
    },
    lsp = "dockerls",
  })
end

return M
