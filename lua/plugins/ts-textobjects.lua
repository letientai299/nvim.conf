-- Treesitter-aware structural navigation: ]m/[m (function), ]]/[[ (class),
-- ]o/[o (conditional/loop). Upgrades Vim's regex-based ]m and ]] builtins.
-- Also makes all moves repeatable with ;/,.
return {
  "nvim-treesitter/nvim-treesitter-textobjects",
  branch = "main",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  event = "VeryLazy",
  config = function()
    require("nvim-treesitter-textobjects").setup({
      move = { set_jumps = true },
    })

    local move = require("nvim-treesitter-textobjects.move")
    local ts_repeat = require("nvim-treesitter-textobjects.repeatable_move")
    local modes = { "n", "x", "o" }

    -- stylua: ignore
    local motions = {
      { "]m", function() move.goto_next_start("@function.outer", "textobjects") end, "Next function start" },
      { "[m", function() move.goto_previous_start("@function.outer", "textobjects") end, "Prev function start" },
      { "]M", function() move.goto_next_end("@function.outer", "textobjects") end, "Next function end" },
      { "[M", function() move.goto_previous_end("@function.outer", "textobjects") end, "Prev function end" },
      { "]]", function() move.goto_next_start("@class.outer", "textobjects") end, "Next class start" },
      { "[[", function() move.goto_previous_start("@class.outer", "textobjects") end, "Prev class start" },
      { "][", function() move.goto_next_end("@class.outer", "textobjects") end, "Next class end" },
      { "[]", function() move.goto_previous_end("@class.outer", "textobjects") end, "Prev class end" },
      { "]o", function() move.goto_next_start({ "@conditional.outer", "@loop.outer" }, "textobjects") end, "Next conditional/loop" },
      { "[o", function() move.goto_previous_start({ "@conditional.outer", "@loop.outer" }, "textobjects") end, "Prev conditional/loop" },
      { "]O", function() move.goto_next_end({ "@conditional.outer", "@loop.outer" }, "textobjects") end, "Next conditional/loop end" },
      { "[O", function() move.goto_previous_end({ "@conditional.outer", "@loop.outer" }, "textobjects") end, "Prev conditional/loop end" },
    }

    local function set_motions(buf)
      local opts_for = buf
          and function(desc)
            return { desc = desc, buffer = buf }
          end
        or function(desc)
          return { desc = desc }
        end
      for _, m in ipairs(motions) do
        vim.keymap.set(modes, m[1], m[2], opts_for(m[3]))
      end
    end

    -- Set global maps now.
    set_motions(nil)

    -- Re-apply as buffer-local after ftplugins that shadow ]m, ]], etc.
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup(
        "TsTextobjectsOverride",
        { clear = true }
      ),
      pattern = { "python", "ruby", "gdscript", "eiffel" },
      callback = function(ev)
        set_motions(ev.buf)
      end,
    })

    -- Make ; and , repeat the last treesitter move (and builtin f/F/t/T).
    vim.keymap.set(modes, ";", ts_repeat.repeat_last_move_next)
    vim.keymap.set(modes, ",", ts_repeat.repeat_last_move_previous)
    vim.keymap.set(modes, "f", ts_repeat.builtin_f_expr, { expr = true })
    vim.keymap.set(modes, "F", ts_repeat.builtin_F_expr, { expr = true })
    vim.keymap.set(modes, "t", ts_repeat.builtin_t_expr, { expr = true })
    vim.keymap.set(modes, "T", ts_repeat.builtin_T_expr, { expr = true })
  end,
}
