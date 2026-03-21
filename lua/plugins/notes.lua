return {
  dir = vim.fn.stdpath("config") .. "/plugins/notes.nvim",
  cmd = "NoteToday",
  config = function()
    vim.api.nvim_create_user_command("NoteToday", function()
      require("notes").note_today()
    end, { desc = "Open/append to today's diary note" })
  end,
}
