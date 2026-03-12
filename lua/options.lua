vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Write a copy instead of rename, preserves file watchers and hard links
vim.opt.backupcopy = "yes"

-- 2-space indentation with spaces (no tabs)
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2

-- Line numbers: absolute + relative for easy jump-counting
vim.opt.number = true
-- vim.opt.relativenumber = true

-- Highlight the line the cursor is on
vim.opt.cursorline = true

-- Disable the fixed-column ruler (0 = off)
vim.opt.colorcolumn = "0"

-- No soft wrapping — long lines scroll horizontally
vim.opt.wrap = false

-- Persistent undo across sessions, stored in undodir
vim.opt.undofile = true

-- Always show the sign column to prevent layout jitter
vim.opt.signcolumn = "yes:1"

-- Case-insensitive search unless the pattern has uppercase
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Start with all folds open
vim.opt.foldenable = false
vim.opt.foldlevel = 99

-- Spell-check language (activate per buffer with :set spell)
vim.opt.spelllang = "en_us"

-- Shorter timeout for mapped key sequences (default 1000ms)
vim.opt.timeoutlen = 300

-- Hide concealed text in normal and command-line mode
vim.opt.concealcursor = "nc"

-- Replace ~ end-of-buffer markers with blank space
vim.opt.fillchars:append({ eob = " " })

-- Auto-insert comment leader when pressing Enter in insert mode
vim.opt.formatoptions:append("r")

-- Scroll by screen line, not by text line (smooth half-line scrolling)
vim.opt.smoothscroll = true

-- Load per-project .nvim.lua if present (sandboxed since 0.9)
vim.opt.exrc = true

-- Fuzzy matching for native completion (0.11+)
vim.opt.completeopt:append("fuzzy")

-- Rounded borders on every floating window globally (0.11+)
vim.o.winborder = "rounded"

-- Diagnostics: show float on jump, virtual text inline, severity signs
vim.diagnostic.config({
  jump = { float = true },
  virtual_text = { spacing = 4, prefix = "●" },
  severity_sort = true,
})

vim.api.nvim_create_user_command("GitRoot", function()
  local root = vim.fs.root(0, ".git")
  if root then
    vim.fn.chdir(root)
    vim.notify(root)
  else
    vim.notify("Not in a git repo", vim.log.levels.WARN)
  end
end, {})
