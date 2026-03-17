local M = {}
local stylua = require("lib.stylua")

function M.setup(bufnr)
  require("langs.shared.entry").setup("lua", bufnr, {
    tools = {
      { bin = "lua-language-server", mise = "lua-language-server" },
      stylua.tool(),
    },
    lsp = "lua_ls",
    formatters = { "stylua" },
  })
end

return M
