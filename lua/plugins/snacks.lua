return {
  "folke/snacks.nvim",
  keys = {
    {
      "<Leader>go",
      function()
        require("snacks").gitbrowse()
      end,
      mode = { "n", "v" },
      desc = "Open in browser",
    },
    {
      "<Leader>gO",
      function()
        require("snacks").gitbrowse({
          open = function(url)
            vim.fn.setreg("+", url)
            vim.notify("Copied: " .. url, vim.log.levels.INFO)
          end,
        })
      end,
      mode = { "n", "v" },
      desc = "Copy git URL",
    },
  },
  opts = {
    gitbrowse = { enabled = true },
  },
}
