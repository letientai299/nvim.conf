local map = vim.keymap.set

map("i", "jk", "<Esc>")
map("v", "jk", "<Esc>")
map("t", "<C-[><C-[>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

if vim.v.vim_did_enter == 1 then
  require("keymaps_late")
else
  vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    once = true,
    callback = function()
      require("keymaps_late")
    end,
  })
end
