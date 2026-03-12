return {
  "lewis6991/gitsigns.nvim",
  lazy = true,
  init = function()
    local augroup = vim.api.nvim_create_augroup("defer_gitsigns", { clear = true })

    local function load_gitsigns(bufnr)
      if vim.g.defer_gitsigns_loaded then
        return
      end

      if vim.bo[bufnr].buftype ~= "" then
        return
      end

      vim.g.defer_gitsigns_loaded = true

      vim.schedule(function()
        require("lazy").load({ plugins = { "gitsigns.nvim" } })
      end)
    end

    vim.api.nvim_create_autocmd("VimEnter", {
      group = augroup,
      once = true,
      callback = function()
        local bufnr = vim.api.nvim_get_current_buf()
        if vim.api.nvim_buf_get_name(bufnr) == "" then
          return
        end
        load_gitsigns(bufnr)
      end,
    })

    vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
      group = augroup,
      callback = function(args)
        if vim.v.vim_did_enter == 0 then
          return
        end
        load_gitsigns(args.buf)
      end,
    })
  end,
  opts = {
    preview_config = {
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
      for _, dir in ipairs({
        { "]c", gs.next_hunk, "Next change" },
        { "[c", gs.prev_hunk, "Prev change" },
      }) do
        bmap("n", dir[1], function()
          if vim.wo.diff then
            vim.cmd.normal({ dir[1], bang = true })
            return
          end
          dir[2]()
        end, dir[3])
      end

      -- Stage / reset
      bmap({ "n", "v" }, "<Leader>gs", gs.stage_hunk, "Stage hunk")
      bmap({ "n", "v" }, "<Leader>gr", gs.reset_hunk, "Reset hunk")
      bmap("n", "<Leader>gS", gs.stage_buffer, "Stage buffer")
      bmap("n", "<Leader>gR", gs.reset_buffer, "Reset buffer")

      -- Preview / blame
      bmap("n", "<Leader>gp", gs.preview_hunk_inline, "Preview hunk")
      bmap("n", "<Leader>gB", gs.toggle_current_line_blame, "Toggle line blame")
      bmap("n", "<Leader>gb", function()
        gs.blame_line({ full = true })
      end, "Blame line (full)")

      -- Diff
      bmap("n", "<Leader>gd", gs.diffthis, "Diff this")

      -- Hunk text object
      bmap({ "o", "x" }, "ih", gs.select_hunk, "Hunk text object")
    end,
  },
}
