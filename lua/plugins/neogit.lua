return {
  "NeogitOrg/neogit",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "sindrets/diffview.nvim",
    "barrettruth/diffs.nvim",
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
  opts = function()
    return {
      graph_style = "kitty",
      remember_settings = true,
      use_per_project_settings = true,
      integrations = { diffview = true },
    }
  end,
}
