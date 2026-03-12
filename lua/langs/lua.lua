require("lib.tools").check("lua", {
  { name = "lua-language-server", bin = "lua-language-server", kind = "lsp" },
  { name = "stylua", bin = "stylua", kind = "fmt" },
})

vim.lsp.enable("lua_ls")

return {
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      enabled = function(root_dir)
        return not vim.uv.fs_stat(root_dir .. "/.luarc.json")
      end,
    },
  },
  {
    "saghen/blink.cmp",
    opts = {
      sources = {
        per_filetype = {
          lua = { inherit_defaults = true, "lazydev" },
        },
        providers = {
          lazydev = {
            name = "LazyDev",
            module = "lazydev.integrations.blink",
            score_offset = 100,
          },
        },
      },
    },
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "lua", "luadoc" } },
  },
}
