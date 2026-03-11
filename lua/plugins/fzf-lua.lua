-- Gitignored dirs to include in the file picker (searched recursively).
local include_dirs = { ".ai.dump", ".dump" }

-- Gitignored files to include in the file picker (matched at project root).
local include_files = { ".envrc", ".exrc", ".nvim.lua" }

--- Build an fd command that respects .gitignore but also finds the exceptions.
local function files_cmd()
  -- Base: respect .gitignore, show hidden, skip .git
  local parts = { "fd --hidden --type f -E .git" }

  -- Append gitignored dirs (--no-ignore scoped to those paths only)
  if #include_dirs > 0 then
    local search_paths = table.concat(
      vim.tbl_map(function(d) return "--search-path " .. d end, include_dirs),
      " "
    )
    table.insert(parts, "fd --hidden --no-ignore --type f -E .git " .. search_paths .. " 2>/dev/null")
  end

  -- Append gitignored individual files
  if #include_files > 0 then
    table.insert(parts, "find " .. table.concat(include_files, " ") .. " -maxdepth 0 2>/dev/null")
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
    { "<leader>fd", "<Cmd>FzfLua diagnostics_document<CR>", desc = "Diagnostics (buffer)" },
    { "<leader>fD", "<Cmd>FzfLua diagnostics_workspace<CR>", desc = "Diagnostics (workspace)" },
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
    { "<leader>fs", "<Cmd>FzfLua lsp_document_symbols<CR>", desc = "LSP symbols (buffer)" },
    { "<leader>fS", "<Cmd>FzfLua lsp_workspace_symbols<CR>", desc = "LSP symbols (workspace)" },
    { "<leader>fx", "<Cmd>FzfLua commands<CR>", desc = "Commands" },
    { "<leader>f/", "<Cmd>FzfLua grep_cword<CR>", desc = "Grep word under cursor" },
    { "<leader>f/", "<Cmd>FzfLua grep_visual<CR>", mode = "x", desc = "Grep selection" },
  },
  config = function()
    require("fzf-lua").setup({
      files = { cmd = files_cmd() },
    })
    require("fzf-lua").register_ui_select()
  end,
}
