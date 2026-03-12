-- Oil: file manager that edits the filesystem like a buffer

local M = {}

local prev_search = ""

--- Save the current search register, set it to the current filename,
--- then open oil at `dir`. Pressing `n` in oil jumps to that file entry.
function M.save_search_and_open(dir)
  prev_search = vim.fn.getreg("/")
  vim.fn.setreg("/", vim.fn.expand("%:t"))
  require("oil").open(dir)
end

--- Restore the search register saved by `save_search_and_open`.
--- No-op if nothing was saved.
function M.restore_search()
  if prev_search == "" then
    return
  end
  vim.fn.setreg("/", prev_search)
  prev_search = ""
end

--- Return the git repo root for cwd, or nil outside a repo.
function M.git_root()
  local out = vim.trim(vim.fn.system("git rev-parse --show-toplevel"))
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return out
end

--- Copy the entry path under cursor to the system clipboard (`+` register).
function M.copy_filepath()
  require("oil.actions").copy_entry_path.callback()
  vim.fn.setreg("+", vim.fn.getreg(vim.v.register))
end

--- Toggle between icon-only and full detail columns (permissions, size, mtime).
function M.toggle_detail()
  local oil = require("oil")
  local cols = oil.get_columns and oil.get_columns() or {}
  if #cols > 1 then
    oil.set_columns({ "icon" })
  else
    oil.set_columns({ "icon", "permissions", "size", "mtime" })
  end
end

return {
  "stevearc/oil.nvim",
  lazy = false,
  priority = 900,
  keys = {
    {
      [[<C-\>]],
      function()
        M.save_search_and_open(vim.fn.expand("%:p:h"))
      end,
      desc = "Oil: current file's directory",
    },
    {
      [[<A-\>]],
      function()
        M.save_search_and_open(M.git_root())
      end,
      desc = "Oil: git root",
    },
  },
  opts = {
    view_options = { show_hidden = true },
    skip_confirm_for_simple_edits = true,
    keymaps = {
      ["yp"] = {
        desc = "Copy filepath to system clipboard",
        callback = M.copy_filepath,
      },
      ["gd"] = { desc = "Toggle file detail view", callback = M.toggle_detail },
    },
  },
  config = function(_, opts)
    require("oil").setup(opts)
    vim.api.nvim_create_autocmd("BufLeave", {
      pattern = "oil://*",
      callback = M.restore_search,
    })
  end,
}
