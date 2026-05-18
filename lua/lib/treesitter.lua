local api = vim.api
local M = {}

local default_languages_registered = false
local known_rtp_entries = {} ---@type table<string, boolean>
local highlighter_destroy_patched = false
local bufenter_autocmd_registered = false

--- Monkey-patch TSHighlighter:destroy to avoid a hang during :bdelete.
---
--- When treesitter's highlighter is destroyed it clears b:ts_highlight (sets
--- it to nil) then fires FileType via the syntaxset group. The syntaxset
--- handler checks `if !exists('b:ts_highlight')` and, when the variable is
--- gone, runs `set syntax=<ft>`. For markdown that sources syntax/markdown.vim
--- → syntax/html.vim and many sub-syntaxes inside nvim_buf_call on a buffer
--- that's mid-deletion, which hangs until Ctrl-C.
---
--- Fix: set b:ts_highlight to false (not nil) so syntaxset sees the variable
--- exists and skips the expensive syntax reload.
--- https://github.com/neovim/neovim/blob/master/runtime/lua/vim/treesitter/highlighter.lua
local function patch_highlighter_destroy()
  if highlighter_destroy_patched then
    return
  end

  local TSHighlighter = vim.treesitter.highlighter
  local ns = api.nvim_create_namespace("nvim.treesitter.highlighter")

  function TSHighlighter:destroy()
    TSHighlighter.active[self.bufnr] = nil

    if api.nvim_buf_is_loaded(self.bufnr) then
      vim.bo[self.bufnr].spelloptions = self.orig_spelloptions
      vim.b[self.bufnr].ts_highlight = false -- not nil → syntaxset skips
      api.nvim_buf_clear_namespace(self.bufnr, ns, 0, -1)
      if vim.g.syntax_on == 1 then
        api.nvim_buf_call(self.bufnr, function()
          api.nvim_exec_autocmds("FileType", {
            group = "syntaxset",
            buffer = self.bufnr,
            modeline = false,
          })
        end)
      end
    end
  end

  highlighter_destroy_patched = true
end

local function ensure_rtp_entry(path)
  if known_rtp_entries[path] then
    return
  end
  if not vim.uv.fs_stat(path) then
    return
  end

  for _, entry in ipairs(vim.opt.rtp:get()) do
    if entry == path then
      known_rtp_entries[path] = true
      return
    end
  end

  vim.opt.rtp:append(path)
  known_rtp_entries[path] = true
end

function M.ensure_runtime()
  ensure_rtp_entry(vim.fs.joinpath(vim.fn.stdpath("data"), "site"))
end

function M.register_default_languages()
  if default_languages_registered then
    return
  end
  default_languages_registered = true
  vim.treesitter.language.register(
    "tsx",
    { "typescriptreact", "javascriptreact" }
  )
  vim.treesitter.language.register("bash", { "sh" })
  vim.treesitter.language.register("json", { "jsonc" })
  vim.treesitter.language.register("c_sharp", { "cs" })
  vim.treesitter.language.register("markdown", { "mdx", "md" })
end

--- Retry highlighting for buffers where tree-sitter-manager auto-installed a
--- parser after our FileType autocmd already fired. On FileType the parser
--- isn't compiled yet, so enable_highlight fails and sets b:ts_highlight=false.
--- BufEnter fires on buffer switch; CursorHold catches same-buffer installs
--- after updatetime idle. Both are cheap — just check the flag and retry.
local function register_bufenter_retry()
  if bufenter_autocmd_registered then
    return
  end
  bufenter_autocmd_registered = true

  api.nvim_create_autocmd({ "BufEnter", "CursorHold" }, {
    group = api.nvim_create_augroup("TsHighlightRetry", { clear = true }),
    callback = function(ev)
      if vim.b[ev.buf].ts_highlight ~= false then
        return
      end
      if vim.bo[ev.buf].buftype ~= "" then
        return
      end
      M.enable_highlight(ev.buf)
    end,
  })
end

function M.enable_highlight(bufnr, filetype)
  if not bufnr or not api.nvim_buf_is_valid(bufnr) then
    return false
  end

  if vim.bo[bufnr].buftype ~= "" then
    vim.b[bufnr].ts_highlight = false
    return false
  end

  M.ensure_runtime()
  M.register_default_languages()
  patch_highlighter_destroy()

  local active = vim.treesitter.highlighter.active[bufnr]
  if active then
    vim.b[bufnr].ts_highlight = true
    if type(filetype) == "string" and filetype ~= "" then
      vim.b[bufnr].current_syntax = filetype
    end
    return true
  end

  local ft = filetype
  if type(ft) ~= "string" or ft == "" then
    ft = vim.bo[bufnr].filetype
  end
  local lang = ft ~= "" and vim.treesitter.language.get_lang(ft) or nil

  local ok
  if vim.b[bufnr].current_syntax then
    api.nvim_buf_call(bufnr, function()
      vim.cmd.syntax("clear")
    end)
    vim.b[bufnr].current_syntax = nil
  end
  if type(lang) == "string" and lang ~= "" then
    ok = pcall(vim.treesitter.start, bufnr, lang)
  else
    ok = pcall(vim.treesitter.start, bufnr)
  end

  vim.b[bufnr].ts_highlight = ok
  if ok and type(ft) == "string" and ft ~= "" then
    vim.b[bufnr].current_syntax = ft
  end

  return ok
end

function M.request_highlight(bufnr, filetype)
  if not bufnr or not api.nvim_buf_is_valid(bufnr) then
    return
  end

  if vim.bo[bufnr].buftype ~= "" then
    vim.b[bufnr].ts_highlight = false
    return
  end

  local ft = filetype
  if type(ft) ~= "string" or ft == "" then
    ft = vim.bo[bufnr].filetype
  end
  if ft == "" then
    return
  end

  M.enable_highlight(bufnr, ft)
  register_bufenter_retry()
end

return M
