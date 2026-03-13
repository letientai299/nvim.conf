return {
  "saghen/blink.cmp",
  event = "InsertEnter",
  build = "cargo build --release",
  dependencies = {
    "L3MON4D3/LuaSnip",
  },
  opts = {
    keymap = { preset = "default" },
    completion = {
      documentation = { auto_show = true },
      menu = {
        draw = {
          columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "source_name" } },
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
        lazydev = {
          name = "LazyDev",
          module = "lazydev.integrations.blink",
          score_offset = 100,
        },
        kitty_pane = {
          name = "kitty",
          module = "blink.sources.kitty-pane",
          score_offset = 5,
        },
      },
    },
    fuzzy = { implementation = "prefer_rust" },
  },
  config = function(_, opts)
    -- Append kitty_pane to whatever sources.default ends up being after all specs merge
    table.insert(opts.sources.default, "kitty_pane")
    require("blink.cmp").setup(opts)
  end,
}
