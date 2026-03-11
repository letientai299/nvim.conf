return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  build = function()
    require("nvim-treesitter").install({
      "bash", "c", "c_sharp", "css", "go", "gomod", "gosum",
      "html", "javascript", "json", "lua", "markdown",
      "markdown_inline", "mermaid", "tsx", "typescript",
      "vim", "vimdoc", "xml", "yaml", "query",
    })
  end,
  lazy = false,
  config = function()
    require("nvim-treesitter").setup({})

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
