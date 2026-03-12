local bufnr = vim.api.nvim_get_current_buf()
require("langs.shared.vue").setup(bufnr)
require("langs.shared.tailwind").setup(bufnr)
