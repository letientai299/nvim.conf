local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("hurl", bufnr, {
    tools = { { bin = "hurlfmt", mise = "hurl" } },
    formatters = { "hurlfmt" },
  })
end

return M
