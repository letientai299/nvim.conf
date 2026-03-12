return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  opts_extend = { "ensure_installed" },
  opts = {
    ensure_installed = {
      "c", "c_sharp", "css", "html", "javascript", "json",
      "mermaid", "tsx", "typescript", "vim", "vimdoc",
      "xml", "yaml", "query",
    },
  },
  config = function(_, opts)
    require("nvim-treesitter").setup({})
    require("nvim-treesitter").install(opts.ensure_installed, { summary = false })

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
