local function yank(method)
  return function()
    local y = require("yanker")
    y[method](y.buf_path())
  end
end

return {
  dir = vim.fn.stdpath("config") .. "/plugins/yanker.nvim",
  keys = {
    { "<Leader>yn", yank("name"), desc = "Copy filename" },
    { "<Leader>yp", yank("relative"), desc = "Copy relative path" },
    { "<Leader>yP", yank("absolute"), desc = "Copy absolute path" },
    { "<Leader>yg", yank("git"), desc = "Copy path from git root" },
    {
      "<Leader>yd",
      function()
        require("yanker").diagnostic()
      end,
      desc = "Copy diagnostic with path:line",
    },
  },
}
