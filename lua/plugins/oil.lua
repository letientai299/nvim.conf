-- Oil: file manager that edits the filesystem like a buffer

local M = {}

local prev_search ---@type string?
local detail_columns = { "permissions", "size", "mtime" }

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
  if prev_search == nil then
    return
  end
  vim.fn.setreg("/", prev_search)
  prev_search = nil
end

--- Return the git repo root for cwd, or nil outside a repo.
function M.git_root()
  return vim.fs.root(0, ".git")
end

--- Copy the entry path under cursor to the system clipboard (`+` register).
function M.copy_filepath()
  require("oil.actions").copy_entry_path.callback()
  vim.fn.setreg("+", vim.fn.getreg(vim.v.register))
end

--- Toggle between filename-only and detail columns (permissions, size, mtime).
function M.toggle_detail()
  local oil = require("oil")
  local cols = oil.get_columns and oil.get_columns() or {}
  if #cols > 0 then
    oil.set_columns({})
  else
    oil.set_columns(detail_columns)
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
    columns = {},
    view_options = {
      show_hidden = true,
      highlight_filename = highlight_filename,
    },
    skip_confirm_for_simple_edits = true,
    keymaps = {
      ["yp"] = {
        desc = "Copy filepath to system clipboard",
        callback = M.copy_filepath,
      },
      ["gd"] = { desc = "Toggle file detail view", callback = M.toggle_detail },
    },
  },
  -- No init needed: lazy = false lets oil register its own BufAdd
  -- handler at startup, which hijacks directory buffers for both
  -- `nvim <dir>` and `:e <dir>` cases.
  config = function(_, opts)
    local oil_util = require("oil.util")
    oil_util.get_icon_provider = function()
      return nil
    end

    set_filetype_highlights()
    require("oil").setup(opts)

    local group = vim.api.nvim_create_augroup("UserOilConfig", { clear = true })
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
}
