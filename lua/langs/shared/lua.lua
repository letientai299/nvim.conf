local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("lua", bufnr, {
    tools = {
      {
        bin = "lua-language-server",
        kind = "lsp",
        mise = "lua-language-server",
      },
      { bin = "stylua", kind = "fmt", mise = "stylua" },
    },
    lsp = "lua_ls",
    formatters = { "stylua" },
  })
end

return M
