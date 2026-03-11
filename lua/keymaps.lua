-- Keymaps, commands, and autocmds ported from vimrc / common.vim

local map = vim.keymap.set

-- ---------------------------------------------------------------------------
-- Escape
-- ---------------------------------------------------------------------------

map("i", "jk", "<Esc>")
map("v", "jk", "<Esc>")
map("t", "<C-[><C-[>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- ---------------------------------------------------------------------------
-- System clipboard
-- ---------------------------------------------------------------------------

map({ "n", "v" }, "<Leader>p", [["+p]], { desc = "Paste from system clipboard" })
map({ "n", "v" }, "<Leader>P", [["+P]], { desc = "Paste before from system clipboard" })
map({ "n", "v" }, "<Leader>y", [["+y]], { desc = "Copy to system clipboard" })
map({ "n", "v" }, "<Leader>Y", [["+Y]], { desc = "Copy line to system clipboard" })

-- ---------------------------------------------------------------------------
-- Center after search
-- ---------------------------------------------------------------------------

map("n", "n", "nzz")
map("n", "N", "Nzz")
map("n", "*", "*zz")
map("n", "#", "#zz")

-- ---------------------------------------------------------------------------
-- Cmdline history navigation
-- ---------------------------------------------------------------------------

map("c", "<C-p>", "<Up>")
map("c", "<C-n>", "<Down>")

-- ---------------------------------------------------------------------------
-- Create file from path under cursor
-- ---------------------------------------------------------------------------

--- Create the file under cursor if it doesn't exist, then open it.
local function create_file()
  local path = vim.fn.expand("<cfile>")
  if path == "" then return end
  if not vim.uv.fs_stat(path) then
    local dir = vim.fn.fnamemodify(path, ":h")
    if dir ~= "." and not vim.uv.fs_stat(dir) then
      vim.fn.mkdir(dir, "p")
    end
  end
  vim.cmd.edit(path)
end

map("n", "<Leader>cf", create_file, { desc = "Create file from path under cursor" })
map("n", "<Leader>w", "<Cmd>Dirsv<CR>", { desc = "Dirsv" })

-- ---------------------------------------------------------------------------
-- Commands
-- ---------------------------------------------------------------------------

vim.api.nvim_create_user_command("SudoWrite", function()
  vim.cmd("w !sudo tee % > /dev/null")
  vim.cmd.edit({ bang = true })
end, { desc = "Write file with sudo" })

vim.api.nvim_create_user_command("Reload", function()
  local config = vim.fn.stdpath("config") .. "/lua/"
  for mod, _ in pairs(package.loaded) do
    local path = package.searchpath(mod, package.path)
    if path and path:find(config, 1, true) then
      package.loaded[mod] = nil
    end
  end
  dofile(vim.fn.stdpath("config") .. "/init.lua")
  vim.notify("Config reloaded", vim.log.levels.INFO)
end, { desc = "Invalidate Lua cache and reload config" })

vim.api.nvim_create_user_command("BufOnly", function()
  local cur = vim.api.nvim_get_current_buf()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= cur and vim.bo[buf].buflisted then
      vim.api.nvim_buf_delete(buf, {})
    end
  end
end, { desc = "Close all buffers except current" })

-- ---------------------------------------------------------------------------
-- Autocmds
-- ---------------------------------------------------------------------------

local augroup = vim.api.nvim_create_augroup("UserConfig", { clear = true })

-- Trigger autoread when focus returns or buffer is entered.
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
  group = augroup,
  command = "silent! checktime",
})

-- Warn when a file changes on disk.
vim.api.nvim_create_autocmd("FileChangedShellPost", {
  group = augroup,
  callback = function()
    vim.notify("File changed on disk. Buffer reloaded.", vim.log.levels.WARN)
  end,
})

-- Hide end-of-buffer tildes after colorscheme loads.
vim.api.nvim_create_autocmd("ColorScheme", {
  group = augroup,
  callback = function()
    vim.api.nvim_set_hl(0, "EndOfBuffer", { fg = "bg" })
  end,
})

-- Markdown: enable proper comment leaders for lists and quotes.
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  group = augroup,
  pattern = "*.md",
  callback = function()
    vim.opt_local.comments = "fb:>,fb:*,fb:+,fb:-"
  end,
})

-- Azure DevOps Definitions files → confini filetype.
vim.api.nvim_create_autocmd("BufEnter", {
  group = augroup,
  pattern = "*Definitions.*",
  callback = function()
    vim.bo.filetype = "confini"
  end,
})

-- ---------------------------------------------------------------------------
-- Abbreviations
-- ---------------------------------------------------------------------------

vim.cmd.iabbrev("ref refactor:")
vim.cmd.iabbrev("ans **Answer**:")
