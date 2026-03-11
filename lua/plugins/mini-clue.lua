return {
  "nvim-mini/mini.clue",
  lazy = false,
  config = function()
    local miniclue = require("mini.clue")

    -- Remap <C-w>hjkl from navigation to resize (submode keeps you in <C-w>).
    -- Navigation is still available via <C-w><C-h/j/k/l>.
    local map = vim.keymap.set
    map("n", "<C-w>h", "<Cmd>vertical resize -2<CR>", { desc = "Resize left" })
    map("n", "<C-w>j", "<Cmd>resize +2<CR>", { desc = "Resize down" })
    map("n", "<C-w>k", "<Cmd>resize -2<CR>", { desc = "Resize up" })
    map("n", "<C-w>l", "<Cmd>vertical resize +2<CR>", { desc = "Resize right" })

    miniclue.setup({
      triggers = {
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
        { mode = "n", keys = '"' },
        { mode = "x", keys = '"' },
        { mode = "i", keys = "<C-r>" },
        { mode = "c", keys = "<C-r>" },
        { mode = "n", keys = "'" },
        { mode = "n", keys = "`" },
        { mode = "x", keys = "'" },
        { mode = "x", keys = "`" },
        { mode = "i", keys = "<C-x>" },
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
        miniclue.gen_clues.windows({ submode_move = true, submode_resize = true }),
        miniclue.gen_clues.z(),

        -- Submode for hjkl resize (stay in <C-w> after each press)
        { mode = "n", keys = "<C-w>h", postkeys = "<C-w>" },
        { mode = "n", keys = "<C-w>j", postkeys = "<C-w>" },
        { mode = "n", keys = "<C-w>k", postkeys = "<C-w>" },
        { mode = "n", keys = "<C-w>l", postkeys = "<C-w>" },
      },
    })
  end,
}
