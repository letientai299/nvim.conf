return {
  "catppuccin/nvim",
  name = "catppuccin",
  lazy = true,
  main = "catppuccin",
  opts = {
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
      fzf = true,
      mini = { enabled = true },
      native_lsp = { enabled = true },
      treesitter = true,
    },
  },
  themes = {
    "catppuccin-latte",
    "catppuccin-frappe",
    "catppuccin-macchiato",
    "catppuccin-mocha",
  },
}
