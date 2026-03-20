return {
  "stevearc/aerial.nvim",
  cmd = { "AerialToggle", "AerialNavToggle" },
  keys = {
    { "<C-F11>", "<Cmd>AerialToggle!<CR>", desc = "Toggle outline" },
    { "<F35>", "<Cmd>AerialToggle!<CR>", desc = "Toggle outline" },
  },
  opts = {
    layout = {
      default_direction = "right",
    },
    lsp = {},
    -- Sync folds with the symbol tree
    manage_folds = true,
    link_folds_to_tree = true,
    link_tree_to_folds = true,
  },
}
