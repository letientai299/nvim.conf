local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("cmake", bufnr, {
    tools = {
      { bin = "cmake", mise = "cmake" },
      { bin = "neocmakelsp", mise = "github:neocmakelsp/neocmakelsp" },
    },
    lsp = "neocmake",
  })
end

return M
