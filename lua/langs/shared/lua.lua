local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("lua", bufnr, {
    tools = {
      { bin = "lua-language-server", mise = "lua-language-server" },
      { bin = "stylua", mise = "stylua" },
    },
    lsp = "lua_ls",
    formatters = { "stylua" },
  })
end

return M
