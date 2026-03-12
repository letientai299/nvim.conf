return {
  "bluz71/vim-moonfly-colors",
  name = "moonfly",
  lazy = true,
  init = function()
    vim.g.moonflyItalics = true
    vim.g.moonflyNormalFloat = true
    vim.g.moonflyVirtualTextColor = true
    vim.g.moonflyUndercurls = true
  end,
  themes = {
    "moonfly",
  },
}
