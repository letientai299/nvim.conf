return {
  "goolord/alpha-nvim",
  cmd = "Alpha",
  init = function()
    local stdin_read = false

    vim.api.nvim_create_autocmd("StdinReadPre", {
      callback = function()
        stdin_read = true
      end,
    })

    vim.api.nvim_create_autocmd("VimEnter", {
      once = true,
      callback = function()
        local is_empty_start = vim.fn.argc() == 0
          and #vim.api.nvim_list_uis() > 0
          and not stdin_read
          and vim.bo[0].buftype == ""
          and vim.api.nvim_buf_get_name(0) == ""
          and not vim.bo[0].modified
          and vim.api.nvim_buf_line_count(0) == 1
          and vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == ""

        if is_empty_start then
          vim.bo.buflisted = false
          vim.cmd.Alpha()
        end
      end,
    })
  end,
  config = function()
    local cfg = require("alpha.themes.startify")
    cfg.section.header.val = {}
    require("alpha").setup(cfg.config)
  end,
}
