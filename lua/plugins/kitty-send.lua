return {
  dir = vim.fn.stdpath("config") .. "/plugins/kitty-send.nvim",
  cmd = { "KittySend", "KittySendThis" },
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
    {
      "<Leader>kt",
      ":KittySendThis<CR>",
      mode = { "n", "x" },
      desc = "Send file path/range to a Kitty pane",
    },
  },
  config = function()
    vim.api.nvim_create_user_command("KittySend", function(opts)
      require("kitty-send").send(opts)
    end, {
      range = true,
      bang = true,
      nargs = "*",
      desc = "Send buffer or visual selection to a visible Kitty pane",
    })
    vim.api.nvim_create_user_command("KittySendThis", function(opts)
      require("kitty-send").send_this(opts)
    end, {
      range = true,
      bang = true,
      nargs = "*",
      desc = "Send file path or line range to a Kitty pane",
    })
  end,
}
