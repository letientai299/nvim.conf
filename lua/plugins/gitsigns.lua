return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    preview_config = {
      border = "rounded",
      style = "minimal",
      relative = "cursor",
      row = 0,
      col = 1,
    },
    on_attach = function(bufnr)
      local gs = require("gitsigns")
      local map = vim.keymap.set

      local function bmap(mode, lhs, rhs, desc)
        map(mode, lhs, rhs, { buffer = bufnr, desc = desc })
      end

      -- Navigation
      for _, dir in ipairs({ { "]h", "]c", gs.next_hunk, "Next hunk" }, { "[h", "[c", gs.prev_hunk, "Prev hunk" } }) do
        bmap("n", dir[1], function()
          if vim.wo.diff then
            vim.cmd.normal({ dir[2], bang = true })
            return
          end
          dir[3]()
        end, dir[4])
      end

      -- Stage / reset
      bmap({ "n", "v" }, "<Leader>gs", gs.stage_hunk, "Stage hunk")
      bmap({ "n", "v" }, "<Leader>gr", gs.reset_hunk, "Reset hunk")
      bmap("n", "<Leader>gS", gs.stage_buffer, "Stage buffer")
      bmap("n", "<Leader>gR", gs.reset_buffer, "Reset buffer")

      -- Preview / blame
      bmap("n", "<Leader>gp", gs.preview_hunk_inline, "Preview hunk")
      bmap("n", "<Leader>gb", gs.toggle_current_line_blame, "Toggle line blame")
      bmap("n", "<Leader>gB", function() gs.blame_line({ full = true }) end, "Blame line (full)")

      -- Diff
      bmap("n", "<Leader>gd", gs.diffthis, "Diff this")

      -- Hunk text object
      bmap({ "o", "x" }, "ih", gs.select_hunk, "Hunk text object")
    end,
  },
}
