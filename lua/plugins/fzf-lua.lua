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
    -- File listing uses scripts/fzf-files (also in dotfiles/bin for shell
    -- ctrl-t). Config (include_dirs, include_files) lives in that script.
    local fzf_files = vim.fn.stdpath("config") .. "/scripts/fzf-files"
    require("fzf-lua").setup({
      files = { cmd = fzf_files },
      previewers = {
        builtin = {
          snacks_image = { enabled = true },
        },
      },
    })
    require("fzf-lua").register_ui_select()
  end,
}
