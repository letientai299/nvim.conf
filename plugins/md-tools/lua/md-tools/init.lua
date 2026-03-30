local M = {}

---@param buf integer
local function apply(buf)
  vim.bo[buf].shiftwidth = 2
  vim.bo[buf].tabstop = 2
  vim.bo[buf].softtabstop = 2

  require("md-tools.checklist").setup_keymaps()
  require("md-tools.codeblock").setup_keymaps()
  require("md-tools.markers").setup_keymaps()
  require("md-tools.markers").setup(buf)
  require("md-tools.gx").setup_keymaps()
end

function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("md-tools", { clear = true }),
    pattern = { "markdown", "mdx" },
    callback = function(ev)
      apply(ev.buf)
    end,
  })

  -- Apply to already-open markdown buffers (plugin loaded via ft trigger).
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local ft = vim.bo[buf].filetype
      if ft == "markdown" or ft == "mdx" then
        vim.api.nvim_buf_call(buf, function()
          apply(buf)
        end)
      end
    end
  end
end

return M
