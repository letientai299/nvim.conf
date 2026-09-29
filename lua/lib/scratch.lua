local M = {}

function M.setup()
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      if
        vim.fn.argc(-1) > 0
        or vim.tbl_contains(vim.v.argv, "-")
        or #vim.api.nvim_list_uis() == 0
      then
        return
      end

      local buf = vim.api.nvim_get_current_buf()
      local cwd = vim.fn.getcwd()
      local function untouched()
        return vim.api.nvim_get_current_buf() == buf
          and vim.fn.getcwd() == cwd
          and vim.api.nvim_buf_get_name(buf) == ""
          and vim.bo[buf].buftype == ""
          and not vim.bo[buf].modified
          and vim.api.nvim_buf_line_count(buf) == 1
          and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
      end

      vim.schedule(function()
        if not untouched() then
          return
        end
        require("lib.lazy_ondemand").on_load("snacks.nvim", function()
          if untouched() then
            require("snacks").scratch({ win = { position = "current" } })
            if
              vim.api.nvim_buf_is_valid(buf)
              and #vim.fn.win_findbuf(buf) == 0
              and not vim.bo[buf].modified
            then
              vim.api.nvim_buf_delete(buf, {})
            end
          end
        end)
        require("lazy").load({ plugins = { "snacks.nvim" } })
      end)
    end,
  })
end

return M
