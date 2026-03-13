-- Gitignored dirs to include in the file picker (searched recursively).
-- Supports fd glob syntax: ".ai.dump" (literal), "**/local" (any depth).
local include_dirs = { ".ai.dump", ".dump", "**/local" }

-- Gitignored files to include in the file picker (matched at any depth).
-- Supports glob wildcard: ".env" (literal), ".env.*" (wildcard).
local include_files = { ".envrc", ".exrc", ".nvim.lua", ".env", ".env.*" }

local function has_glob(s)
  return s:find("[*?%[]") ~= nil
end

--- Convert an fd glob pattern to a full-path regex.
--- e.g. "**/local" -> "/local/"
local function glob_to_path_regex(pat)
  return "/"
    .. pat:gsub("%*%*/", ""):gsub("%.", "\\."):gsub("%*", "[^/]*")
    .. "/"
end

--- Build an fd command that respects .gitignore but also finds the exceptions.
--- Two fd calls: one gitignore-aware base, one --no-ignore with a combined
--- full-path regex for all exception dirs and root files.
local function files_cmd()
  -- Base: respect .gitignore, show hidden, skip .git
  local parts = { "fd --hidden --type f -E .git" }

  -- Build a single regex that matches all gitignored exceptions.
  local alts = {}

  for _, d in ipairs(include_dirs) do
    if has_glob(d) then
      -- **/local -> /local/  (substring match at any depth)
      table.insert(alts, glob_to_path_regex(d))
    else
      -- .ai.dump -> /\.ai\.dump/  (substring match; fd normalises away leading ./)
      table.insert(alts, "/" .. d:gsub("%.", "\\.") .. "/")
    end
  end

  if #include_files > 0 then
    -- {".envrc", ".env.*"} -> /\.(envrc|env\..*)$
    local file_alts = vim.tbl_map(function(f)
      return f:sub(2):gsub("%.", "\\."):gsub("%*", ".*")
    end, include_files)
    table.insert(alts, "/\\.(" .. table.concat(file_alts, "|") .. ")$")
  end

  if #alts > 0 then
    local regex = table.concat(alts, "|")
    table.insert(
      parts,
      "fd --hidden --no-ignore -E .git --type f --full-path "
        .. vim.fn.shellescape(regex)
        .. " 2>/dev/null"
    )
  end

  return "{ " .. table.concat(parts, " & ") .. "; wait; } | sort -u"
end

return {
  "ibhagwan/fzf-lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  cmd = "FzfLua",
  keys = {
    { "<A-f>", "<Cmd>FzfLua buffers<CR>", desc = "Buffers" },
    { "<leader>f?", "<Cmd>FzfLua help_tags<CR>", desc = "Help tags" },
    { "<leader>fa", "<Cmd>FzfLua builtin<CR>", desc = "All pickers" },
    { "<leader>fc", "<Cmd>FzfLua git_bcommits<CR>", desc = "Buffer commits" },
    { "<leader>fC", "<Cmd>FzfLua git_commits<CR>", desc = "All commits" },
    {
      "<leader>fd",
      "<Cmd>FzfLua diagnostics_document<CR>",
      desc = "Diagnostics (buffer)",
    },
    {
      "<leader>fD",
      "<Cmd>FzfLua diagnostics_workspace<CR>",
      desc = "Diagnostics (workspace)",
    },
    { "<leader>ff", "<Cmd>FzfLua files<CR>", desc = "Files" },
    { "<leader>fF", "<Cmd>FzfLua git_files<CR>", desc = "Git files" },
    { "<leader>fg", "<Cmd>FzfLua live_grep<CR>", desc = "Live grep" },
    { "<leader>fG", "<Cmd>FzfLua git_status<CR>", desc = "Git status" },
    { "<leader>fh", "<Cmd>FzfLua oldfiles<CR>", desc = "Recent files" },
    { "<leader>fl", "<Cmd>FzfLua blines<CR>", desc = "Buffer lines" },
    { "<leader>fm", "<Cmd>FzfLua keymaps<CR>", desc = "Keymaps" },
    { "<leader>f'", "<Cmd>FzfLua marks<CR>", desc = "Marks" },
    { '<leader>f"', "<Cmd>FzfLua registers<CR>", desc = "Registers" },
    { "<leader>fr", "<Cmd>FzfLua lsp_references<CR>", desc = "LSP references" },
    { "<leader>fR", "<Cmd>FzfLua resume<CR>", desc = "Resume last picker" },
    {
      "<leader>fs",
      "<Cmd>FzfLua lsp_document_symbols<CR>",
      desc = "LSP symbols (buffer)",
    },
    {
      "<leader>fS",
      "<Cmd>FzfLua lsp_workspace_symbols<CR>",
      desc = "LSP symbols (workspace)",
    },
    { "<leader>fx", "<Cmd>FzfLua commands<CR>", desc = "Commands" },
    {
      "<leader>f/",
      "<Cmd>FzfLua grep_cword<CR>",
      desc = "Grep word under cursor",
    },
    {
      "<leader>f/",
      "<Cmd>FzfLua grep_visual<CR>",
      mode = "x",
      desc = "Grep selection",
    },
  },
  config = function()
    require("fzf-lua").setup({
      files = { cmd = files_cmd() },
    })
    require("fzf-lua").register_ui_select()
  end,
}
