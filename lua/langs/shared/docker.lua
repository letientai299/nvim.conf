local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("dockerfile", bufnr, {
    tools = {
      {
        bin = "docker-langserver",
        mise = "npm:dockerfile-language-server-nodejs",
        dependencies = { "node" },
      },
    },
    lsp = "dockerls",
  })
end

return M
