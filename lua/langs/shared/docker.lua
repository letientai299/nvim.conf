local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("dockerfile", bufnr, {
    tools = {
      {
        bin = "docker-langserver",
        kind = "lsp",
        mise = "npm:dockerfile-language-server-nodejs",
      },
    },
    lsp = "dockerls",
  })
end

return M
