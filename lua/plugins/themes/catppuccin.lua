return {
  "catppuccin/nvim",
  name = "catppuccin",
  lazy = true,
  main = "catppuccin",
  opts = function()
    return {
      dim_inactive = { enabled = true },
      styles = {
        comments = { "italic" },
        conditionals = { "italic" },
        keywords = { "italic" },
        functions = { "bold" },
        types = { "bold" },
      },
      default_integrations = true,
      integrations = {
        alpha = true,
        blink_cmp = true,
        diffview = true,
        fzf = true,
        gitsigns = true,
        mini = { enabled = true },
        native_lsp = { enabled = true },
        neogit = true,
        treesitter = true,
      },
    }
  end,
  themes = {
    "catppuccin-latte",
    "catppuccin-frappe",
    "catppuccin-macchiato",
    "catppuccin-mocha",
  },
}
