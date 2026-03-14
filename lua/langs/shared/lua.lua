local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("lua", bufnr, {
    tools = {
      {
        name = "lua-language-server",
        bin = "lua-language-server",
        kind = "lsp",
      },
      { name = "stylua", bin = "stylua", kind = "fmt" },
    },
    lsp = "lua_ls",
    formatters = { "stylua" },
  })
end

return M
