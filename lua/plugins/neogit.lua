local lazy_require = require("lib.lazy_ondemand").lazy_require

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
        lazy_require("neogit").open()
      end,
      desc = "Neogit status",
    },
    {
      "<Leader>gl",
      function()
        lazy_require("neogit").open({ "log" })
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
