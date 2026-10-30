local M = {}

function M.setup(bufnr)
  local bin = (vim.env.ELAN_HOME or vim.fn.expand("~/.elan")) .. "/bin"
  if not vim.tbl_contains(vim.split(vim.env.PATH, ":"), bin) then
    vim.env.PATH = vim.env.PATH .. ":" .. bin
  end

  require("langs.shared.entry").setup("lean", bufnr, {
    tools = { { bin = "lean", script = "install-lean.sh" } },
    each = function(buf)
      require("lib.lazy_ondemand").on_load("lean.nvim", function()
        if
          not vim.api.nvim_buf_is_loaded(buf)
          or vim.bo[buf].filetype ~= "lean"
        then
          return
        end
        vim.api.nvim_buf_call(buf, function()
          vim.cmd("runtime! ftplugin/lean/*.lua")
          if vim.b.current_syntax ~= "lean" then
            vim.cmd("runtime! syntax/lean.vim")
          end
        end)
      end)
      require("lazy").load({ plugins = { "lean.nvim" } })
    end,
  })
end

return M
