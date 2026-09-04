return {
  dir = vim.fn.stdpath("config") .. "/plugins/notes.nvim",
  cmd = { "NoteToday", "NoteMonth" },
  keys = {
    { "<leader>vd", "<Cmd>NoteToday<CR>", desc = "Open today's diary note" },
    { "<leader>vm", "<Cmd>NoteMonth<CR>", desc = "Open monthly note" },
  },
  config = function()
    vim.api.nvim_create_user_command("NoteToday", function()
      require("notes").note_today()
    end, { desc = "Open/append to today's diary note" })
    vim.api.nvim_create_user_command("NoteMonth", function()
      require("notes").note_month()
    end, { desc = "Open this month's diary note" })
  end,
}
