local M = {}

local function attach_enabled_configs(bufnr)
  pcall(vim.api.nvim_exec_autocmds, "FileType", {
    group = "nvim.lsp.enable",
    buffer = bufnr,
    modeline = false,
  })
end

--- Enable an LSP config and attach it to the current buffer when needed.
--- @param name string
--- @param bufnr integer|nil
function M.enable(name, bufnr)
  vim.lsp.enable(name)

  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  if vim.v.vim_did_enter == 1 then
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        attach_enabled_configs(bufnr)
      end
    end)
    return
  end

  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        attach_enabled_configs(bufnr)
      end
    end,
  })
end

return M
