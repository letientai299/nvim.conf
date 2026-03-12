return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  opts = {
    ensure_installed = { "query", "vim", "vimdoc" },
  },
  config = function(_, opts)
    require("nvim-treesitter").setup({})
    require("nvim-treesitter").install(
      opts.ensure_installed,
      { summary = false }
    )
    require("lib.lang_registry").activate_treesitter()

    vim.api.nvim_create_autocmd("FileType", {
      callback = function()
        if pcall(vim.treesitter.start) then
          vim.wo[0][0].foldmethod = "expr"
          vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
        end
      end,
    })
  end,
}
