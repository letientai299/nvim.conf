return {
  dir = vim.fn.stdpath("config") .. "/plugins/web-grep",
  name = "web-grep.nvim",
  keys = {
    {
      "<Leader>sw",
      function()
        require("web-grep").search()
      end,
      mode = "n",
      desc = "Web search cword",
    },
    {
      "<Leader>sw",
      function()
        require("web-grep").search({ visual = true })
      end,
      mode = "x",
      desc = "Web search selection",
    },
    {
      "<Leader>sW",
      function()
        require("web-grep").search({ prompt = true })
      end,
      mode = "n",
      desc = "Web search (prompt)",
    },
    {
      "<Leader>sW",
      function()
        require("web-grep").search({ prompt = true, visual = true })
      end,
      mode = "x",
      desc = "Web search selection (prompt)",
    },
  },
  config = function()
    require("web-grep").setup()
  end,
}
