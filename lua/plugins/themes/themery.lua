local catalog = require("plugins.themes.catalog")

return {
  "zaldih/themery.nvim",
  cmd = "Themery",
  keys = {
    { "<leader>ft", "<Cmd>Themery<CR>", desc = "Colorschemes" },
  },
  config = function()
    require("themery").setup({
      themes = catalog.collect_themes(),
      livePreview = true,
      -- Reset background before each switch so hooks from the previous theme
      -- don't leak (e.g., vim.opt.background = "light" persisting into a dark theme)
      globalBefore = [[vim.opt.background = "dark"]],
    })
  end,
}
