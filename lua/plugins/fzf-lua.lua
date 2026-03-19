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

--- Shell snippet that queries git for ignored directories and emits -E flags
--- so the --no-ignore fd call skips heavy dirs it would otherwise traverse.
--- Uses git's own gitignore processing (handles nested .gitignore files,
--- global gitignore, etc.) instead of manual parsing.
--- @param skip string[] directory names to NOT exclude (our include_dirs)
local function git_ignored_dirs_sh(skip)
  local skip_grep = ""
  if #skip > 0 then
    skip_grep = " | grep -vxF " .. vim.fn.shellescape(table.concat(skip, "\n"))
  end
  return "$("
    .. "git ls-files --others --ignored --exclude-standard --directory 2>/dev/null"
    .. " | grep '/$' | sed 's/\\/$//'"
    .. skip_grep
    .. " | sed 's/.*/-E &/' | tr '\\n' ' '"
    .. ")"
end

--- Build an fd command that respects .gitignore but also finds the exceptions.
--- Three parallel fd calls:
---  1. Base (gitignore-aware) for normal files.
---  2. Direct search inside concrete include_dirs (fast: dirs are small).
---  3. --no-ignore scan for glob dirs + include_files, with -E flags derived
---     from .gitignore to avoid traversing heavy ignored dirs.
local function files_cmd()
  local parts = { "fd --hidden --type f -E .git" }

  -- Split include_dirs into concrete paths vs glob patterns.
  local concrete_dirs = {}
  local glob_alts = {}
  for _, d in ipairs(include_dirs) do
    if has_glob(d) then
      table.insert(glob_alts, glob_to_path_regex(d))
    else
      table.insert(concrete_dirs, d)
    end
  end

  -- Search concrete gitignored dirs directly (avoids whole-tree traversal).
  if #concrete_dirs > 0 then
    local paths = vim.tbl_map(function(d)
      return "--search-path " .. vim.fn.shellescape(d)
    end, concrete_dirs)
    table.insert(
      parts,
      "fd --no-ignore --hidden --type f -E .git "
        .. table.concat(paths, " ")
        .. " 2>/dev/null"
    )
  end

  -- Glob dirs and include_files need a whole-tree --no-ignore scan.
  local alts = vim.list_extend({}, glob_alts)
  if #include_files > 0 then
    local file_alts = vim.tbl_map(function(f)
      return f:sub(2):gsub("%.", "\\."):gsub("%*", ".*")
    end, include_files)
    table.insert(alts, "/\\.(" .. table.concat(file_alts, "|") .. ")$")
  end

  if #alts > 0 then
    local regex = table.concat(alts, "|")
    table.insert(
      parts,
      "fd --hidden --no-ignore -E .git "
        .. git_ignored_dirs_sh(concrete_dirs)
        .. " --type f --full-path "
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
      "<Cmd>FzfLua lsp_live_workspace_symbols<CR>",
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
    -- snacks.image must be loaded before fzf-lua's builtin previewer checks
    -- _G.Snacks.image. fzf-lua is already lazy (cmd = "FzfLua"), so this
    -- only runs on first use, not at startup.
    if not package.loaded["snacks"] then
      require("lazy").load({ plugins = { "snacks.nvim" } })
    end
    require("fzf-lua").setup({
      files = { cmd = files_cmd() },
      previewers = {
        builtin = {
          snacks_image = { enabled = true },
        },
      },
    })
    require("fzf-lua").register_ui_select()
  end,
}
