-- User commands, autocmds, and abbreviations

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

vim.api.nvim_create_user_command("AutoFormat", function()
  require("conform").format({ async = true, lsp_fallback = true })
end, { desc = "Format current buffer with conform.nvim" })

vim.api.nvim_create_user_command("LocalTodo", function()
  local git_dir = vim.fn.system("git rev-parse --git-common-dir 2>/dev/null"):gsub("%s+$", "")
  if vim.v.shell_error ~= 0 or git_dir == "" then
    vim.notify("Not a git repo", vim.log.levels.ERROR)
    return
  end
  local repo = vim.fn.fnamemodify(git_dir, ":h")
  vim.fn.mkdir(repo .. "/.dump", "p")
  vim.cmd.edit(repo .. "/.dump/todo.md")
end, { desc = "Open per-repo todo file at .dump/todo.md" })

vim.api.nvim_create_user_command("BufOnly", function()
  local cur = vim.api.nvim_get_current_buf()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= cur and vim.bo[buf].buflisted then
      vim.api.nvim_buf_delete(buf, {})
    end
  end
end, { desc = "Close all buffers except current" })

-- AutoCopy: stub that lazy-loads the real implementation on first use
vim.api.nvim_create_user_command("AutoCopy", function()
  require("autocopy").toggle()
end, { desc = "Toggle auto-copy buffer content to clipboard" })

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
    local bg = vim.api.nvim_get_hl(0, { name = "Normal" }).bg
    if bg then
      vim.api.nvim_set_hl(0, "EndOfBuffer", { fg = bg })
    end
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
