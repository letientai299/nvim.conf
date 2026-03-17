vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Write a copy instead of rename, preserves file watchers and hard links
vim.opt.backupcopy = "yes"

-- 2-space indentation with spaces (no tabs)
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2

-- stable UI, no layout shifts
vim.opt.laststatus = 2
vim.opt.showtabline = 2

-- Line numbers: absolute + relative for easy jump-counting
vim.opt.number = true
-- vim.opt.relativenumber = true

-- Highlight the line the cursor is on
vim.opt.cursorline = true

-- Column ruler at textwidth (editorconfig/prettier can override per-buffer)
vim.opt.colorcolumn = "+0"

-- Soft-wrap long lines at window edge (avoids horizontal scroll from ghost text)
vim.opt.wrap = true
vim.opt.linebreak = true

-- Persistent undo across sessions, stored in undodir
vim.opt.undofile = true

-- Always show the sign column to prevent layout jitter
vim.opt.signcolumn = "yes:1"

-- Case-insensitive search unless the pattern has uppercase
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Spell-check language (activate per buffer with :set spell)
vim.opt.spelllang = "en_us"

local augroup = vim.api.nvim_create_augroup("UserOptions", { clear = true })

-- Prefer treesitter highlighting for normal file buffers without waiting for
-- the full nvim-treesitter plugin config to load.
vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
  group = augroup,
  callback = function(args)
    if vim.bo[args.buf].buftype == "" then
      vim.b[args.buf].ts_highlight = false
    end
  end,
})

local function is_normal_file_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  if vim.bo[bufnr].buftype ~= "" then
    return false
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  if name:find("://", 1, true) then
    return false
  end

  if name ~= "" and vim.fn.isdirectory(name) == 1 then
    return false
  end

  return true
end

vim.api.nvim_create_autocmd("FileType", {
  group = augroup,
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    if not is_normal_file_buffer(buf) then
      return
    end

    local ft = vim.bo[buf].filetype
    if ft == "" then
      return
    end

    local lib_ts = require("lib.treesitter")
    lib_ts.request_highlight(buf, ft)
  end,
})

-- Shorter timeout for mapped key sequences (default 1000ms)
vim.opt.timeoutlen = 300

-- Hide concealed text in normal and command-line mode
vim.opt.concealcursor = "nc"

-- Show invisible characters
vim.opt.list = false
vim.opt.listchars = {
  tab = "» ",
  lead = "·",
  trail = "·",
  nbsp = "␣",
  extends = "…",
  precedes = "…",
  eol = "↲",
}

-- Swap eol icon: thin ↲ for LF, bold ⏎ for CRLF
vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
  group = augroup,
  callback = function()
    local eol = vim.bo.fileformat == "dos" and "⏎" or "↲"
    vim.opt_local.listchars:append({ eol = eol })
  end,
})

-- Replace ~ end-of-buffer markers with blank space
vim.opt.fillchars:append({ eob = " " })

-- Auto-insert comment leader when pressing Enter in insert mode;
-- hard-wrap text while typing at textwidth boundary.
vim.opt.formatoptions:append("rtc")
vim.opt.textwidth = 80

-- Scroll by screen line, not by text line (smooth half-line scrolling)
vim.opt.smoothscroll = true

-- Load per-project .nvim.lua if present (sandboxed since 0.9)
vim.opt.exrc = true

-- Fuzzy matching for native completion (0.11+)
vim.opt.completeopt:append("fuzzy")

-- Rounded borders on every floating window globally (0.11+)
vim.o.winborder = "rounded"

-- Settings deferred until VeryLazy to avoid loading vim.diagnostic and
-- treesitter fold code at startup. On :Reload (vim_did_enter == 1) VeryLazy
-- has already fired, so apply immediately.
local function apply_deferred_options()
  vim.opt.foldmethod = "expr"
  vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
  vim.opt.foldtext = "" -- render first line with syntax highlighting (0.10+)
  vim.opt.foldlevel = 99
  vim.opt.foldlevelstart = 99

  vim.diagnostic.config({
    jump = { float = true },
    virtual_text = { spacing = 4, prefix = "●" },
    severity_sort = true,
  })

  -- Override textwidth from prettier printWidth when a config exists nearby.
  local function apply_prettier_tw(bufnr)
    if is_normal_file_buffer(bufnr) then
      require("lib.prettier").resolve_print_width(bufnr)
    end
  end

  vim.api.nvim_create_autocmd("BufEnter", {
    group = augroup,
    callback = function(args)
      apply_prettier_tw(args.buf)
    end,
  })

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    apply_prettier_tw(buf)
  end
end

if vim.v.vim_did_enter == 1 then
  apply_deferred_options()
else
  vim.api.nvim_create_autocmd("User", {
    group = augroup,
    pattern = "VeryLazy",
    once = true,
    callback = apply_deferred_options,
  })
end

vim.api.nvim_create_user_command("GitRoot", function()
  local root = vim.fs.root(0, ".git")
  if root then
    vim.fn.chdir(root)
    vim.notify(root)
  else
    vim.notify("Not in a git repo", vim.log.levels.WARN)
  end
end, {})
