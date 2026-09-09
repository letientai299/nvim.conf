-- Standalone side-by-side diffs and file history. Also loaded as a neogit
-- dependency for its diffview integration — see neogit.lua.
--
-- https://github.com/sindrets/diffview.nvim
return {
  "sindrets/diffview.nvim",
  cmd = {
    "DiffviewOpen",
    "DiffviewClose",
    "DiffviewFileHistory",
    "DiffviewToggleFiles",
    "DiffviewFocusFiles",
    "DiffviewRefresh",
  },
  keys = {
    { "<Leader>gD", "<Cmd>DiffviewOpen<CR>", desc = "Diff view" },
  },
  config = function()
    require("diffview").setup({
      view = {
        default = { layout = "diff2_vertical" },
        file_history = { layout = "diff2_vertical" },
      },
    })
  end,
}
