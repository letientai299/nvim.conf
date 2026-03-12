return {
  "folke/lazydev.nvim",
  ft = "lua",
  opts = {
    enabled = function(root_dir)
      return not vim.uv.fs_stat(root_dir .. "/.luarc.json")
    end,
  },
}
