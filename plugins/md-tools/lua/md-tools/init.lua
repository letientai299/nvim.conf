local M = {}

---@param buf integer
local function apply(buf)
  local notebook = require("lib.notebook")
  local myst = notebook.is_myst(buf)
  local width = myst and 4 or 2
  vim.bo[buf].shiftwidth = width
  vim.bo[buf].tabstop = width
  vim.bo[buf].softtabstop = width

  require("md-tools.checklist").setup_keymaps()
  require("md-tools.codeblock").setup_keymaps()
  require("md-tools.markers").setup_keymaps()
  require("md-tools.markers").setup(buf)
  require("md-tools.gx").setup_keymaps()
  require("md-tools.at-path").setup(buf)
  require("md-tools.fence-lines").setup(buf)
  require("md-tools.textobjects").setup(buf)
  notebook.setup_editing(buf)
end

function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("md-tools", { clear = true }),
    pattern = { "markdown", "mdx", "quarto" },
    callback = function(ev)
      apply(ev.buf)
    end,
  })

  -- Apply to already-open markdown buffers (plugin loaded via ft trigger).
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local ft = vim.bo[buf].filetype
      if ft == "markdown" or ft == "mdx" or ft == "quarto" then
        vim.api.nvim_buf_call(buf, function()
          apply(buf)
        end)
      end
    end
  end
end

return M
