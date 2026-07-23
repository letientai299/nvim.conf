return {
  dir = vim.fn.stdpath("config") .. "/plugins/kitty-send.nvim",
  cmd = "KittySend",
  keys = {
    {
      "<Leader>ks",
      ":KittySend<CR>",
      mode = { "n", "x" },
      desc = "Send buffer/selection to a Kitty pane",
    },
    {
      "<Leader>kS",
      ":KittySend!<CR>",
      mode = { "n", "x" },
      desc = "Send buffer/selection to last Kitty pane",
    },
  },
  config = function()
    vim.api.nvim_create_user_command("KittySend", function(opts)
      require("kitty-send").send(opts)
    end, {
      range = true,
      bang = true,
      desc = "Send buffer or visual selection to a visible Kitty pane",
    })
  end,
}
