local bufnr = vim.api.nvim_get_current_buf()
require("langs.shared.html").setup(bufnr)
require("langs.shared.tailwind").setup(bufnr)
