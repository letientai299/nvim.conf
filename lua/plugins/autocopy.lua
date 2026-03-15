return {
  dir = vim.fn.stdpath("config") .. "/plugins/autocopy.nvim",
  cmd = "AutoCopy",
  config = function()
    vim.api.nvim_create_user_command("AutoCopy", function()
      require("autocopy").toggle()
    end, { desc = "Toggle auto-copy buffer content to clipboard" })
  end,
}
