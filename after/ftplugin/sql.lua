local nav = require("lib.nav_keys")

--- Jump to the next or previous top-level SQL statement via treesitter.
--- SQL tree: (program (statement ...) (comment) (statement ...) ...)
--- We skip comment nodes and only land on `statement` nodes.
--- Falls back to semicolon search when no treesitter parser is available.
---@param forward boolean
local function goto_statement(forward)
  vim.cmd("normal! m'")

  local ok, parser = pcall(vim.treesitter.get_parser, 0, "sql")
  if not ok or not parser then
    vim.fn.search(";", forward and "W" or "bW")
    return
  end

  -- trees() returns the cached parse; avoids a full reparse on every jump.
  local trees = parser:trees()
  if #trees == 0 then
    return
  end

  local root = trees[1]:root()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local count = root:named_child_count()
  local from, to, step = 0, count - 1, 1
  if not forward then
    from, to, step = count - 1, 0, -1
  end

  for i = from, to, step do
    local child = root:named_child(i)
    if child and child:type() == "statement" then
      local start_row = child:range()
      if (forward and start_row > row) or (not forward and start_row < row) then
        vim.api.nvim_win_set_cursor(0, { start_row + 1, 0 })
        return
      end
    end
  end
end

vim.keymap.set("n", nav.next, function()
  goto_statement(true)
end, {
  buffer = true,
  desc = "Next SQL statement",
})

vim.keymap.set("n", nav.prev, function()
  goto_statement(false)
end, {
  buffer = true,
  desc = "Prev SQL statement",
})
