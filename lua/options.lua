vim.g.mapleader = " "
vim.g.maplocalleader = " "

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

-- Disable the fixed-column ruler (0 = off)
vim.opt.colorcolumn = "80"

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

-- Treesitter-based folding, start with all folds open
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldtext = "" -- render first line with syntax highlighting (0.10+)
vim.opt.foldlevelstart = 99

-- Skip runtime syntax scripts when a treesitter parser is installed.
-- synload.vim registers an ungrouped `Syntax *` → `s:SynSet()` handler that
-- sources runtime syntax files. We replace it after synload.vim finishes.
vim.api.nvim_create_autocmd("SourcePost", {
  pattern = "*/syntax/synload.vim",
  once = true,
  callback = function()
    vim.cmd("au! Syntax *")
    vim.api.nvim_create_autocmd("Syntax", {
      pattern = "*",
      callback = function()
        local syntax = vim.fn.expand("<amatch>")
        if syntax == "" or syntax == "ON" or syntax == "OFF" then
          return
        end
        local lang = vim.treesitter.language.get_lang(syntax)
        if lang and pcall(vim.treesitter.language.inspect, lang) then
          vim.b.current_syntax = syntax
          return
        end
        vim.cmd.syntax("clear")
        vim.cmd("runtime! syntax/" .. vim.fn.fnameescape(syntax) .. ".vim")
      end,
    })
  end,
})

-- Spell-check language (activate per buffer with :set spell)
vim.opt.spelllang = "en_us"

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
  callback = function()
    local eol = vim.bo.fileformat == "dos" and "⏎" or "↲"
    vim.opt_local.listchars:append({ eol = eol })
  end,
})

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

-- Diagnostics: defer config to avoid loading vim.diagnostic at startup
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  once = true,
  callback = function()
    vim.diagnostic.config({
      jump = { float = true },
      virtual_text = { spacing = 4, prefix = "●" },
      severity_sort = true,
    })
  end,
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
