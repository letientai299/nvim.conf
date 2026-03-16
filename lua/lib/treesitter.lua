local api = vim.api
local M = {}

local default_languages_registered = false
local custom_parsers_registered = false
local custom_parser_autocmd_registered = false
local known_rtp_entries = {} ---@type table<string, boolean>
local startup_highlight_autocmd_registered = false
local startup_highlight_queue = {} ---@type table<integer, string>
local highlighter_destroy_patched = false
local startup_defer_filetypes = nil ---@type table<string, boolean>?
local fallback_syntax_available = {} ---@type table<string, boolean>

local function add_startup_defer_filetype(filetype)
  if type(filetype) ~= "string" or filetype == "" then
    return
  end

  startup_defer_filetypes = startup_defer_filetypes or {}
  startup_defer_filetypes[filetype] = true
end

local function register_startup_defer_filetypes(filetypes)
  if type(filetypes) == "string" then
    add_startup_defer_filetype(filetypes)
    return
  end

  if type(filetypes) ~= "table" then
    return
  end

  for _, filetype in ipairs(filetypes) do
    add_startup_defer_filetype(filetype)
  end
end

local function discover_startup_defer_filetypes()
  if startup_defer_filetypes then
    return startup_defer_filetypes
  end

  startup_defer_filetypes = {}

  local ftplugin_dir = vim.fs.joinpath(vim.fn.stdpath("config"), "ftplugin")
  local ok, iter = pcall(vim.fs.dir, ftplugin_dir)
  if not ok then
    return startup_defer_filetypes
  end

  for name, ftype in iter do
    if ftype == "file" then
      local filetype = name:match("^(.*)%.lua$")
      if filetype then
        startup_defer_filetypes[filetype] = true
      end
    end
  end

  return startup_defer_filetypes
end

local function should_defer_startup(filetype)
  return discover_startup_defer_filetypes()[filetype] == true
end

local function has_fallback_syntax(filetype)
  local cached = fallback_syntax_available[filetype]
  if cached ~= nil then
    return cached
  end

  local found = #api.nvim_get_runtime_file(
    "syntax/" .. filetype .. ".vim",
    true
  ) > 0
  fallback_syntax_available[filetype] = found
  return found
end

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

--- Custom tree-sitter parsers not in nvim-treesitter's built-in list.
local custom_parsers = {
  log = {
    install_info = {
      url = "https://github.com/Tudyx/tree-sitter-log",
      branch = "main",
    },
  },
}

--- Register custom parsers into nvim-treesitter's table.
--- Called on init and on User TSUpdate (nvim-treesitter reloads the table).
local function register_custom_parsers()
  local ok, parsers = pcall(require, "nvim-treesitter.parsers")
  if not ok then
    return
  end
  for lang, spec in pairs(custom_parsers) do
    if not parsers[lang] then
      parsers[lang] = spec
    end
  end
end

local function maybe_register_custom_parsers()
  if
    custom_parsers_registered or not package.loaded["nvim-treesitter.parsers"]
  then
    return
  end

  register_custom_parsers()
  custom_parsers_registered = true

  if custom_parser_autocmd_registered then
    return
  end

  custom_parser_autocmd_registered = true
  -- nvim-treesitter reloads the parsers table on install/update, wiping our
  -- custom entries. Re-register via the documented User TSUpdate hook.
  api.nvim_create_autocmd("User", {
    pattern = "TSUpdate",
    callback = register_custom_parsers,
  })
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
  ensure_rtp_entry(
    vim.fs.joinpath(vim.fn.stdpath("data"), "lazy", "nvim-treesitter")
  )
end

function M.register_default_languages()
  if not default_languages_registered then
    default_languages_registered = true
    vim.treesitter.language.register(
      "tsx",
      { "typescriptreact", "javascriptreact" }
    )
    vim.treesitter.language.register("bash", { "sh" })
    vim.treesitter.language.register("json", { "jsonc" })
    vim.treesitter.language.register("c_sharp", { "cs" })
    vim.treesitter.language.register("markdown", { "mdx" })
  end

  maybe_register_custom_parsers()
end

local function queue_auto_install(bufnr)
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      M.auto_install(bufnr)
    end
  end)
end

local function enable_fallback_syntax(bufnr, filetype)
  if vim.b[bufnr].current_syntax then
    return
  end

  local ft = filetype
  if type(ft) ~= "string" or ft == "" then
    ft = vim.bo[bufnr].filetype
  end
  if ft == "" then
    return
  end

  api.nvim_buf_call(bufnr, function()
    vim.cmd.syntax("clear")
    vim.cmd("runtime! syntax/" .. vim.fn.fnameescape(ft) .. ".vim")
  end)
end

function M.enable_highlight(bufnr, filetype)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
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

local function start_requested_highlight(bufnr, filetype)
  if not M.enable_highlight(bufnr, filetype) then
    queue_auto_install(bufnr)
  end
end

local function flush_startup_highlights()
  local pending = startup_highlight_queue
  startup_highlight_queue = {}

  for bufnr, filetype in pairs(pending) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      start_requested_highlight(bufnr, filetype)
    end
  end
end

local function ensure_startup_highlight_autocmd()
  if startup_highlight_autocmd_registered then
    return
  end

  startup_highlight_autocmd_registered = true
  api.nvim_create_autocmd("UIEnter", {
    once = true,
    callback = function()
      -- Let the first screen draw with the runtime syntax fallback, then swap in
      -- treesitter on the next loop turn.
      vim.schedule(flush_startup_highlights)
    end,
  })
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

  if
    vim.v.vim_did_enter == 0
    and should_defer_startup(ft)
    and has_fallback_syntax(ft)
  then
    enable_fallback_syntax(bufnr, ft)
    startup_highlight_queue[bufnr] = ft
    ensure_startup_highlight_autocmd()
    return
  end

  start_requested_highlight(bufnr, ft)
end

function M.register_startup_defer_filetypes(filetypes)
  register_startup_defer_filetypes(filetypes)
end

local installing = {} ---@type table<string, true?>

--- Install a tool via the shared mise backend (serialized to prevent
--- concurrent writes to config.toml).
---@param tool string   mise package name
---@param label string  human-readable name for notifications
---@param on_done fun(ok: boolean)
local function mise_install(tool, label, on_done)
  vim.notify("Installing " .. label .. "...", vim.log.levels.INFO)
  require("tool-installer.backend.mise").install(tool, nil, function(ok, err)
    vim.schedule(function()
      if ok then
        vim.env.PATH = vim.env.PATH -- rehash for new shims
        vim.notify(label .. " installed.", vim.log.levels.INFO)
      else
        vim.notify(
          "Failed to install " .. label .. ": " .. (err or ""),
          vim.log.levels.ERROR
        )
      end
      on_done(ok)
    end)
  end)
end

--- Ensure a C compiler is available before treesitter parser compilation.
--- Checks cc, gcc, clang, zig in order. When nothing is found, installs zig
--- via mise.
---@param callback fun()
local function ensure_c_compiler(callback)
  for _, cc in ipairs({ "cc", "gcc", "clang" }) do
    if vim.fn.executable(cc) == 1 then
      callback()
      return
    end
  end

  -- zig cc works as a C compiler but CC="zig cc" breaks build systems that
  -- don't shell-expand the value.  Write a tiny wrapper script instead.
  local wrapper = vim.fn.stdpath("cache") .. "/zig-cc"
  local function write_zig_cc_wrapper()
    local f = io.open(wrapper, "w")
    if not f then
      return false
    end
    -- Strip --target flags: zig cc rejects GNU-style triples
    -- (e.g. aarch64-unknown-linux-gnu) that tree-sitter passes.
    -- https://github.com/ziglang/zig/issues/7360
    f:write([=[#!/bin/sh
out=
skip=
for a in "$@"; do
  if [ -n "$skip" ]; then skip=; continue; fi
  case "$a" in
    --target=*) ;;
    --target|-target) skip=1 ;;
    *) out="$out \"$a\"" ;;
  esac
done
eval exec zig cc "$out"
]=])
    f:close()
    vim.fn.setfperm(wrapper, "rwxr-xr-x")
    vim.env.CC = wrapper
    return true
  end

  if vim.fn.executable("zig") == 1 then
    if write_zig_cc_wrapper() then
      callback()
    end
    return
  end

  mise_install("zig", "zig (C compiler for treesitter)", function(ok)
    if ok and write_zig_cc_wrapper() then
      callback()
    end
  end)
end

--- Ensure the tree-sitter CLI is available (nvim-treesitter shells out to
--- `tree-sitter build` to compile parser .so files).
---@param callback fun()
local function ensure_ts_cli(callback)
  if vim.fn.executable("tree-sitter") == 1 then
    callback()
    return
  end

  mise_install("tree-sitter", "tree-sitter CLI", function(ok)
    if ok then
      callback()
    end
  end)
end

--- Ensure all treesitter build prerequisites are met, then call `callback`.
---@param callback fun()
local function ensure_build_deps(callback)
  ensure_ts_cli(function()
    ensure_c_compiler(callback)
  end)
end

--- Auto-install a missing parser for the buffer's filetype, then enable
--- highlighting. Uses nvim-treesitter's async install; re-triggers
--- enable_highlight on completion.
function M.auto_install(bufnr)
  local ft = vim.bo[bufnr].filetype
  if ft == "" then
    return
  end

  local lang = vim.treesitter.language.get_lang(ft) or ft
  if installing[lang] then
    return
  end

  -- In-memory check: if the parser .so is already loaded, skip install
  if pcall(vim.treesitter.language.inspect, lang) then
    return
  end

  M.ensure_runtime()
  if not package.loaded["nvim-treesitter"] then
    pcall(function()
      require("lazy").load({ plugins = { "nvim-treesitter" } })
    end)
  end

  local ok, parsers = pcall(require, "nvim-treesitter.parsers")
  if not ok then
    return
  end
  maybe_register_custom_parsers()
  if not parsers[lang] then
    return -- no parser definition exists in nvim-treesitter
  end

  installing[lang] = true
  ensure_build_deps(function()
    require("nvim-treesitter")
      .install({ lang }, {
        summary = false,
      })
      :await(function()
        installing[lang] = nil
        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(bufnr) then
            return
          end
          M.enable_highlight(bufnr)
          vim.cmd("redraw!")
        end)
      end)
  end)
end

return M
