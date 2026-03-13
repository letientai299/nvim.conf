if vim.v.vim_did_enter == 1 then
  require("commands_late")
else
  vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    once = true,
    callback = function()
      require("commands_late")
    end,
  })
end
