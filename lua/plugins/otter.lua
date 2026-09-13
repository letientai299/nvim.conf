return {
  "jmbuhr/otter.nvim",
  lazy = true,
  dependencies = { "romus204/tree-sitter-manager.nvim" },
  opts = {
    lsp = {
      root_dir = function(_, bufnr)
        bufnr = bufnr or 0
        return vim.fs.root(bufnr, {
          "pyproject.toml",
          "ty.toml",
          "ruff.toml",
          ".ruff.toml",
          ".git",
        }) or vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr))
      end,
    },
  },
}
