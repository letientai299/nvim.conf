-- Gitignored dirs to include in the file picker (searched recursively).
-- Supports fd glob syntax: ".ai.dump" (literal), "**/local" (any depth).
local include_dirs = { ".ai.dump", ".dump", "**/local" }

-- Gitignored files to include in the file picker (matched at project root).
-- Supports find -name glob syntax: ".env" (literal), ".env.*" (wildcard).
local include_files = { ".envrc", ".exrc", ".nvim.lua", ".env", ".env.*" }

local function has_glob(s)
  return s:find("[*?%[]") ~= nil
end

--- Build an fd command that respects .gitignore but also finds the exceptions.
local function files_cmd()
  -- Base: respect .gitignore, show hidden, skip .git
  local parts = { "fd --hidden --type f -E .git" }

  -- Gitignored dirs: literal paths use --search-path (fast, no full scan);
  -- glob patterns resolve matching dirs first, then search files inside.
  local literal, glob = {}, {}
  for _, d in ipairs(include_dirs) do
    table.insert(has_glob(d) and glob or literal, d)
  end

  local fd_noignore = "fd --hidden --no-ignore -E .git"

  if #literal > 0 then
    local paths = vim.tbl_map(function(d)
      return "--search-path " .. vim.fn.shellescape(d)
    end, literal)
    local cmd = fd_noignore .. " --type f " .. table.concat(paths, " ")
    table.insert(parts, cmd .. " 2>/dev/null")
  end

  for _, pat in ipairs(glob) do
    local find_dirs = fd_noignore
      .. " --type d --full-path --glob "
      .. vim.fn.shellescape(pat)
    local search = " | while IFS= read -r d; do "
      .. fd_noignore
      .. ' --type f --search-path "$d"; done 2>/dev/null'
    table.insert(parts, find_dirs .. search)
  end

  -- Gitignored files at project root via find's -name glob matching.
  if #include_files > 0 then
    local names = vim.tbl_map(function(f)
      return "-name " .. vim.fn.shellescape(f)
    end, include_files)
    local match = table.concat(names, " -o ")
    table.insert(
      parts,
      "find . -maxdepth 1 \\( " .. match .. " \\) 2>/dev/null | cut -c3-"
    )
  end

  return "{ " .. table.concat(parts, "; ") .. "; } | sort -u"
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
