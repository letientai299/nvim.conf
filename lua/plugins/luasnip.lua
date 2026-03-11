return {
  "L3MON4D3/LuaSnip",
  version = "v2.*",
  build = "make install_jsregexp",
  dependencies = {
    "rafamadriz/friendly-snippets",
  },
  config = function()
    require("luasnip.loaders.from_vscode").lazy_load({
      include = {
        "go",
        "cs",
        "java",
        "javascript",
        "typescript",
        "javascriptreact",
        "typescriptreact",
        "markdown",
        "shellscript",
        "json",
        "yaml",
        "toml",
        "rust",
        "lua",
        "python",
        "html",
        "css",
        "sql",
      },
    })
    require("luasnip.loaders.from_vscode").lazy_load({
      paths = { vim.fn.stdpath("config") .. "/snippets" },
    })
    require("luasnip.loaders.from_lua").lazy_load({
      paths = { vim.fn.stdpath("config") .. "/lua/snippets" },
    })
  end,
}
