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
    },
    snippets = { preset = "luasnip" },
    sources = {
      default = { "lsp", "snippets", "path", "buffer" },
    },
    fuzzy = { implementation = "prefer_rust" },
  },
}
