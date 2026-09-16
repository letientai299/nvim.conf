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
    local close_view =
      { "n", "gq", "<Cmd>DiffviewClose<CR>", { desc = "Close Diffview" } }
    local function enable_clues(bufnr)
      require("lib.lazy_ondemand").on_load("mini.clue", function()
        if vim.api.nvim_buf_is_valid(bufnr) then
          require("mini.clue").ensure_buf_triggers(bufnr)
        end
      end)
    end

    require("diffview").setup({
      hooks = {
        diff_buf_read = enable_clues,
        view_opened = function(view)
          for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(view.tabpage)) do
            enable_clues(vim.api.nvim_win_get_buf(winid))
          end
        end,
      },
      keymaps = {
        view = { close_view },
        file_panel = { close_view },
        file_history_panel = { close_view },
        option_panel = { close_view },
        help_panel = { close_view },
      },
      view = {
        default = { layout = "diff2_vertical" },
        file_history = { layout = "diff2_vertical" },
      },
    })
  end,
}
