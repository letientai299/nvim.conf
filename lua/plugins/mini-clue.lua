return {
  "nvim-mini/mini.clue",
  event = "VeryLazy",
  config = function()
    local miniclue = require("mini.clue")

    -- <C-e> = window manipulation (resize, rotate, exchange, move-to-edge).
    -- All actions use submode so you can repeat without re-pressing <C-e>.
    -- <C-w> stays for navigation/creation.
    -- stylua: ignore
    local ce_actions = {
      { "h", "<Cmd>vertical resize -2<CR>", "Resize left" },
      { "j", "<Cmd>resize +2<CR>",          "Resize down" },
      { "k", "<Cmd>resize -2<CR>",          "Resize up" },
      { "l", "<Cmd>vertical resize +2<CR>", "Resize right" },
    }

    local ce_postkeys = {}
    for _, action in ipairs(ce_actions) do
      vim.keymap.set("n", "<C-e>" .. action[1], action[2], { desc = action[3] })
      table.insert(
        ce_postkeys,
        { mode = "n", keys = "<C-e>" .. action[1], postkeys = "<C-e>" }
      )
    end

    local textobjects = {
      w = "Word",
      W = "WORD",
      s = "Sentence",
      p = "Paragraph",
      ["("] = "Parentheses, trimmed",
      [")"] = "Parentheses",
      ["["] = "Square brackets, trimmed",
      ["]"] = "Square brackets",
      ["{"] = "Braces, trimmed",
      ["}"] = "Braces",
      ["<"] = "Angle brackets, trimmed",
      [">"] = "Angle brackets",
      b = "Brackets",
      ['"'] = "Double quotes",
      ["'"] = "Single quotes",
      ["`"] = "Backticks",
      q = "Quotes",
      ["?"] = "User prompt",
      a = "Argument",
      f = "Function call",
      t = "Tag",
      F = "Function definition",
      c = "Class",
      o = "Conditional or loop",
      B = "Block",
      l = "Line",
      e = "Entire buffer",
    }
    local function textobject_clues()
      local labels =
        vim.tbl_extend("force", textobjects, vim.b.textobject_labels or {})
      local clues = {}
      for _, mode in ipairs({ "x", "o" }) do
        for _, prefix in ipairs({ "i", "a" }) do
          for key, desc in pairs(labels) do
            if desc then
              table.insert(
                clues,
                { mode = mode, keys = prefix .. key, desc = desc }
              )
            end
          end
        end
      end
      return clues
    end

    miniclue.setup({
      triggers = {
        { mode = "x", keys = "i" },
        { mode = "x", keys = "a" },
        { mode = "o", keys = "i" },
        { mode = "o", keys = "a" },
        { mode = "n", keys = "<Leader>" },
        { mode = "x", keys = "<Leader>" },
        { mode = "n", keys = "[" },
        { mode = "n", keys = "]" },
        { mode = "x", keys = "[" },
        { mode = "x", keys = "]" },
        { mode = "n", keys = "g" },
        { mode = "x", keys = "g" },
        { mode = "n", keys = "z" },
        { mode = "x", keys = "z" },
        { mode = "n", keys = "<C-w>" },
        { mode = "n", keys = "<C-e>" },
        { mode = "n", keys = "s" },
        { mode = "x", keys = "s" },
        { mode = "n", keys = '"' },
        { mode = "x", keys = '"' },
        { mode = "i", keys = "<C-r>" },
        { mode = "c", keys = "<C-r>" },
        { mode = "n", keys = "'" },
        { mode = "n", keys = "`" },
        { mode = "x", keys = "'" },
        { mode = "x", keys = "`" },
        { mode = "n", keys = "<LocalLeader>" },
        { mode = "i", keys = "<C-x>" },
        { mode = "n", keys = "<C-q>" },
        { mode = "t", keys = "<C-q>" },
      },
      window = {
        config = { width = "auto" },
      },
      clues = {
        miniclue.gen_clues.builtin_completion(),
        miniclue.gen_clues.g(),
        miniclue.gen_clues.marks(),
        miniclue.gen_clues.registers(),
        miniclue.gen_clues.square_brackets(),
        miniclue.gen_clues.windows({
          submode_move = false,
          submode_resize = false,
        }),
        miniclue.gen_clues.z(),

        ce_postkeys,
        textobject_clues,
        { mode = "n", keys = "<Leader>a", desc = "+AI" },
        { mode = "x", keys = "<Leader>a", desc = "+AI" },
        { mode = "n", keys = "<Leader>y", desc = "+Copy" },
        { mode = "x", keys = "<Leader>y", desc = "+Copy" },
        { mode = "n", keys = "<Leader>g", desc = "+Git" },
        { mode = "x", keys = "<Leader>g", desc = "+Git" },
        { mode = "n", keys = "<Leader>s", desc = "+Search" },
        { mode = "x", keys = "<Leader>s", desc = "+Search" },
        { mode = "n", keys = "<Leader>c", desc = "+Code" },
        { mode = "n", keys = "<Leader>d", desc = "+Diagnostics" },
        { mode = "n", keys = "<Leader>q", desc = "+Quit" },
        { mode = "n", keys = "<Leader>f", desc = "+Find" },
        { mode = "x", keys = "<Leader>f", desc = "+Find" },
        { mode = "n", keys = "<Leader>k", desc = "+Kitty" },
        { mode = "x", keys = "<Leader>k", desc = "+Kitty" },
        { mode = "n", keys = "<Leader>v", desc = "+Config/Notes" },
        { mode = "n", keys = "<Leader>z", desc = "+Zen" },
        { mode = "i", keys = "<C-x><C-x>", desc = "Disable completion source" },
        {
          mode = "i",
          keys = "<C-x><C-s>",
          desc = "Re-enable completion sources",
        },
        { mode = "n", keys = "<C-q>", desc = "+Terminal" },
        { mode = "t", keys = "<C-q>", desc = "+Terminal" },
      },
    })
  end,
}
