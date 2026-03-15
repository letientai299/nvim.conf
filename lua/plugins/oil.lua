-- Oil: file manager that edits the filesystem like a buffer

local lazy_require = require("lib.lazy_ondemand").lazy_require
local M = {}

local prev_search ---@type string?
local base_columns = { "icon" }
local detail_columns = { "icon", "permissions", "size", "mtime" }

local oil_filetype_hl_links = {
  OilFileCss = "Special",
  OilFileGo = "Type",
  OilFileHtml = "Tag",
  OilFileJs = "Keyword",
  OilFileJson = "Identifier",
  OilFileLua = "Special",
  OilFileMarkdown = "String",
  OilFilePy = "Function",
  OilFileSh = "Statement",
  OilFileToml = "Number",
  OilFileTs = "Constant",
  OilFileYaml = "PreProc",
}

local oil_filetype_hl_by_ext = {
  bash = "OilFileSh",
  cjs = "OilFileJs",
  css = "OilFileCss",
  go = "OilFileGo",
  htm = "OilFileHtml",
  html = "OilFileHtml",
  js = "OilFileJs",
  json = "OilFileJson",
  jsonc = "OilFileJson",
  jsx = "OilFileJs",
  less = "OilFileCss",
  lua = "OilFileLua",
  md = "OilFileMarkdown",
  mdx = "OilFileMarkdown",
  mjs = "OilFileJs",
  py = "OilFilePy",
  sass = "OilFileCss",
  scss = "OilFileCss",
  sh = "OilFileSh",
  toml = "OilFileToml",
  ts = "OilFileTs",
  tsx = "OilFileTs",
  yaml = "OilFileYaml",
  yml = "OilFileYaml",
  zsh = "OilFileSh",
}

local oil_filetype_hl_by_name = {
  [".bashrc"] = "OilFileSh",
  [".bash_profile"] = "OilFileSh",
  [".profile"] = "OilFileSh",
  [".zprofile"] = "OilFileSh",
  [".zshenv"] = "OilFileSh",
  [".zshrc"] = "OilFileSh",
  ["go.mod"] = "OilFileGo",
  ["go.sum"] = "OilFileGo",
}

local function set_filetype_highlights()
  for group, target in pairs(oil_filetype_hl_links) do
    vim.api.nvim_set_hl(0, group, { default = true, link = target })
  end
end

local function file_highlight(name)
  local base = name:match("([^/]+)$") or name
  local by_name = oil_filetype_hl_by_name[base]
  if by_name then
    return by_name
  end

  local ext = base:match("%.([^.]+)$")
  if not ext then
    return nil
  end

  return oil_filetype_hl_by_ext[ext:lower()]
end

local function highlight_filename(
  entry,
  is_hidden,
  is_link_target,
  is_link_orphan
)
  if is_hidden or is_link_target or is_link_orphan or entry.type ~= "file" then
    return nil
  end
  return file_highlight(entry.name)
end

local function directory_buffer_path(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname == "" or bufname:find("://", 1, true) then
    return nil
  end

  if vim.fn.isdirectory(bufname) == 0 then
    return nil
  end

  return vim.fn.fnamemodify(bufname, ":p")
end

local function open_directory_with_oil(bufnr)
  if not directory_buffer_path(bufnr) then
    return false
  end

  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    if not directory_buffer_path(bufnr) then
      return
    end

    require("lazy").load({ plugins = { "oil.nvim" } })

    if not directory_buffer_path(bufnr) then
      return
    end

    local winid = vim.fn.bufwinid(bufnr)
    local open = function()
      local path = directory_buffer_path(bufnr)
      if path then
        lazy_require("oil").open(path)
      end
    end

    if winid ~= -1 and vim.api.nvim_win_is_valid(winid) then
      vim.api.nvim_win_call(winid, open)
    else
      open()
    end
  end)

  return true
end

--- Save the current search register, set it to the current filename,
--- then open oil at `dir`. Pressing `n` in oil jumps to that file entry.
function M.save_search_and_open(dir)
  prev_search = vim.fn.getreg("/")
  vim.fn.setreg("/", vim.fn.expand("%:t"))
  lazy_require("oil").open(dir)
end

--- Restore the search register saved by `save_search_and_open`.
--- No-op if nothing was saved.
function M.restore_search()
  if prev_search == nil then
    return
  end
  vim.fn.setreg("/", prev_search)
  prev_search = nil
end

function M.git_root()
  return vim.fs.root(0, ".git")
end

--- Return the absolute path of the entry under cursor, or nil.
local function cursor_entry_path()
  local oil = require("oil")
  local entry = oil.get_cursor_entry()
  local dir = oil.get_current_dir()
  if not entry or not dir then
    return nil
  end
  return dir .. entry.name
end

function M.yank_name()
  local entry = require("oil").get_cursor_entry()
  if entry then
    require("lib.yanker").put(entry.name)
  end
end

function M.yank_relative()
  require("lib.yanker").relative(cursor_entry_path())
end

function M.yank_absolute()
  require("lib.yanker").absolute(cursor_entry_path())
end

function M.yank_git()
  require("lib.yanker").git(cursor_entry_path())
end

--- Toggle between filename-only and detail columns (permissions, size, mtime).
function M.toggle_detail()
  local oil = require("oil")
  local cols = oil.get_columns and oil.get_columns() or {}
  if #cols > 1 then
    oil.set_columns(base_columns)
  else
    oil.set_columns(detail_columns)
  end
end

return {
  { "refractalize/oil-git-status.nvim", lazy = true },
  {
    "stevearc/oil.nvim",
    priority = 900,
    dependencies = {
      "nvim-tree/nvim-web-devicons",
      "refractalize/oil-git-status.nvim",
    },
    cmd = "Oil",
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
    opts = function()
      return {
        columns = base_columns,
        win_options = {
          signcolumn = "yes:2",
        },
        view_options = {
          show_hidden = true,
          highlight_filename = highlight_filename,
        },
        skip_confirm_for_simple_edits = true,
        watch_for_changes = true,
        keymaps = {
          ["yn"] = { desc = "Yank filename", callback = M.yank_name },
          ["yp"] = { desc = "Yank relative path", callback = M.yank_relative },
          ["yP"] = { desc = "Yank absolute path", callback = M.yank_absolute },
          ["yg"] = { desc = "Yank path from git root", callback = M.yank_git },
          ["<C-p>"] = {
            desc = "Preview (with image support)",
            callback = function()
              -- Load snacks only when previewing an image so its BufReadCmd
              -- autocmds exist and oil uses bufadd instead of raw-byte scratch.
              if not package.loaded["snacks"] then
                local entry = require("oil").get_cursor_entry()
                if
                  entry
                  and entry.type == "file"
                  and require("lib.image").is_image(entry.name)
                then
                  require("lazy").load({ plugins = { "snacks.nvim" } })
                end
              end
              require("oil.actions").preview.callback({
                split = "belowright",
              })
            end,
          },
          ["gd"] = {
            desc = "Toggle file detail view",
            callback = M.toggle_detail,
          },
          ["g?"] = {
            desc = "Show keymaps (sorted by key)",
            callback = function()
              local keymap_util = require("oil.keymap_util")
              local original_sort = table.sort
              rawset(table, "sort", function(t, fn)
                if t[1] and t[1].str and t[1].desc then
                  original_sort(t, function(a, b)
                    return a.str < b.str
                  end)
                else
                  original_sort(t, fn)
                end
              end)
              keymap_util.show_help(require("oil.config").keymaps)
              rawset(table, "sort", original_sort)
            end,
          },
        },
      }
    end,
    init = function()
      local group = vim.api.nvim_create_augroup("UserOilShim", { clear = true })

      vim.api.nvim_create_autocmd("BufEnter", {
        group = group,
        pattern = "*",
        callback = function(args)
          open_directory_with_oil(args.buf)
        end,
      })
    end,
    config = function(_, opts)
      set_filetype_highlights()
      require("oil").setup(opts)
      require("oil-git-status").setup()

      local group =
        vim.api.nvim_create_augroup("UserOilConfig", { clear = true })
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = group,
        callback = set_filetype_highlights,
      })
      vim.api.nvim_create_autocmd("BufLeave", {
        group = group,
        pattern = "oil://*",
        callback = M.restore_search,
      })
    end,
  },
}
