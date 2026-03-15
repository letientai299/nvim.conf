return {
  "saghen/blink.cmp",
  event = "InsertEnter",
  build = "cargo build --release",
  dependencies = {
    "L3MON4D3/LuaSnip",
    {
      dir = vim.fn.stdpath("config") .. "/plugins/blink-cmp-kitty",
      name = "blink-cmp-kitty",
    },
    {
      dir = vim.fn.stdpath("config") .. "/plugins/blink-cmp-path",
      name = "blink-cmp-path",
    },
  },
  opts = function()
    return {
      keymap = { preset = "default" },
      signature = { enabled = true },
      completion = {
        ghost_text = { enabled = true },
        documentation = { auto_show = true },
        menu = {
          draw = {
            columns = {
              { "kind_icon" },
              { "label", "label_description", gap = 1 },
              { "source_name" },
            },
          },
        },
      },
      snippets = { preset = "luasnip" },
      sources = {
        default = { "lsp", "snippets", "path", "buffer" },
        per_filetype = {
          lua = { inherit_defaults = true, "lazydev" },
        },
        providers = {
          path = {
            score_offset = 100,
            opts = {
              show_hidden_files_by_default = true,
            },
          },
          lazydev = {
            name = "LazyDev",
            module = "lazydev.integrations.blink",
            score_offset = 100,
          },
          kitty_pane = {
            name = "kitty",
            module = "blink-cmp-kitty",
            score_offset = -3,
          },
          path_cwd = {
            name = "cwd",
            module = "blink-cmp-path",
            score_offset = 90,
            opts = {
              always_index = { ".ai.dump/**" },
            },
          },
        },
      },
      fuzzy = { implementation = "prefer_rust" },
    }
  end,
  config = function(_, opts)
    -- Append kitty_pane to whatever sources.default ends up being after all specs merge
    table.insert(opts.sources.default, "kitty_pane")
    table.insert(opts.sources.default, "path_cwd")
    require("blink.cmp").setup(opts)
  end,
}
