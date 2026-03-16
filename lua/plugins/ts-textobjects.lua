-- Treesitter-aware structural navigation: ]m/[m (function), ]]/[[ (class),
-- ]o/[o (conditional/loop). Upgrades Vim's regex-based ]m and ]] builtins.
-- <C-j>/<C-k> jump through ALL symbols (classes, fields, methods) in order.
-- All moves are repeatable with ;/,.

--- Check if a treesitter node type represents a declaration/definition.
local function is_decl(t)
  -- stylua: ignore
  return t:match("_declaration$")
    or t:match("_definition$")
    or t:match("_item$")           -- Rust: function_item, struct_item, etc.
    or t == "class_specifier" or t == "struct_specifier"
    or t == "enum_specifier" or t == "union_specifier"
    or t:match("^field") or t:match("^property")
    or t == "decorated_definition" -- Python
    or t == "atx_heading" or t == "setext_heading" -- Markdown
end

--- Collect 0-based row numbers of all symbol declarations in the buffer.
local function get_symbol_rows(bufnr)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return {}
  end
  local trees = parser:parse()
  if not trees or not trees[1] then
    return {}
  end

  local rows, seen = {}, {}
  local function add(node)
    local r = node:start()
    if not seen[r] then
      seen[r] = true
      rows[#rows + 1] = r
    end
  end

  local function walk(node)
    for child in node:iter_children() do
      if child:named() then
        local t = child:type()
        if is_decl(t) then
          add(child)
          -- Recurse into class/struct to find members, but not into functions
          if not (t:match("func") or t:match("method")) then
            walk(child)
          end
        elseif
          t:match("body")
          or t:match("declaration_list")
          or t:match("^export")
          or t == "section"
        then
          -- Descend into structural wrapper nodes
          walk(child)
        end
      end
    end
  end

  walk(trees[1]:root())
  table.sort(rows)
  return rows
end

--- Jump to the next (dir=1) or previous (dir=-1) symbol from cursor.
local function jump_symbol(dir)
  local rows = get_symbol_rows(0)
  if #rows == 0 then
    return
  end
  local cur = vim.api.nvim_win_get_cursor(0)[1] - 1
  local target
  if dir == 1 then
    for _, r in ipairs(rows) do
      if r > cur then
        target = r
        break
      end
    end
  else
    for i = #rows, 1, -1 do
      if rows[i] < cur then
        target = rows[i]
        break
      end
    end
  end
  if not target then
    return
  end
  vim.cmd("normal! m'")
  vim.api.nvim_win_set_cursor(0, { target + 1, 0 })
  vim.cmd("normal! ^")
end

-- Defer loading until first motion keypress instead of BufReadPre.
-- Saves ~3ms on first file open; imperceptible on first keypress.
local modes = { "n", "x", "o" }

-- stylua: ignore
local lazy_keys = {
  -- Structural motions (trigger load on first use)
  { "]m", desc = "Next function start" },
  { "[m", desc = "Prev function start" },
  { "]M", desc = "Next function end" },
  { "[M", desc = "Prev function end" },
  { "]]", desc = "Next class start" },
  { "[[", desc = "Prev class start" },
  { "][", desc = "Next class end" },
  { "[]", desc = "Prev class end" },
  { "]o", desc = "Next conditional/loop" },
  { "[o", desc = "Prev conditional/loop" },
  { "]O", desc = "Next conditional/loop end" },
  { "[O", desc = "Prev conditional/loop end" },
  { "<C-j>", desc = "Next symbol" },
  { "<C-k>", desc = "Prev symbol" },
  -- Repeat integration (f/F/t/T/;/, get ts_repeat wrappers)
  { ";", desc = "Repeat last move (next)" },
  { ",", desc = "Repeat last move (prev)" },
  { "f", desc = "Find char forward" },
  { "F", desc = "Find char backward" },
  { "t", desc = "Till char forward" },
  { "T", desc = "Till char backward" },
}

-- Expand mode into each key entry
for _, k in ipairs(lazy_keys) do
  k.mode = modes
end

return {
  "nvim-treesitter/nvim-treesitter-textobjects",
  branch = "main",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  keys = lazy_keys,
  config = function()
    require("nvim-treesitter-textobjects").setup({
      move = { set_jumps = true },
    })

    local move = require("nvim-treesitter-textobjects.move")
    local ts_repeat = require("nvim-treesitter-textobjects.repeatable_move")

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

    -- <C-j>/<C-k>: jump through all treesitter symbols in document order.
    local jump_sym = ts_repeat.make_repeatable_move(function(opts)
      jump_symbol(opts.forward and 1 or -1)
    end)
    vim.keymap.set(modes, "<C-j>", function()
      jump_sym({ forward = true })
    end, { desc = "Next symbol" })
    vim.keymap.set(modes, "<C-k>", function()
      jump_sym({ forward = false })
    end, { desc = "Prev symbol" })

    -- Make ; and , repeat the last treesitter move (and builtin f/F/t/T).
    vim.keymap.set(modes, ";", ts_repeat.repeat_last_move_next)
    vim.keymap.set(modes, ",", ts_repeat.repeat_last_move_previous)
    vim.keymap.set(modes, "f", ts_repeat.builtin_f_expr, { expr = true })
    vim.keymap.set(modes, "F", ts_repeat.builtin_F_expr, { expr = true })
    vim.keymap.set(modes, "t", ts_repeat.builtin_t_expr, { expr = true })
    vim.keymap.set(modes, "T", ts_repeat.builtin_T_expr, { expr = true })
  end,
}
