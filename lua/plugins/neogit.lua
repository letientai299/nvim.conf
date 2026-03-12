return {
  "NeogitOrg/neogit",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "sindrets/diffview.nvim",
  },
  keys = {
    {
      "<Leader>gg",
      function()
        require("neogit").open()
      end,
      desc = "Neogit status",
    },
    {
      "<Leader>gl",
      function()
        require("neogit").open({ "log" })
      end,
      desc = "Log (branch)",
    },
  },
  opts = {
    integrations = { diffview = true },
  },
}
