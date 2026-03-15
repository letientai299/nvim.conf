return {
  dir = vim.fn.stdpath("config") .. "/plugins/notes.nvim",
  cmd = "NoteToday",
  keys = {
    {
      "<Leader>td",
      function()
        require("notes").note_today()
      end,
      desc = "Open today's diary note",
    },
  },
  config = function()
    vim.api.nvim_create_user_command("NoteToday", function()
      require("notes").note_today()
    end, { desc = "Open/append to today's diary note" })
  end,
}
