return {
  "sainnhe/sonokai",
  lazy = true,
  init = function()
    vim.g.sonokai_enable_italic = 1
    vim.g.sonokai_dim_inactive_windows = 1
    vim.g.sonokai_better_performance = 1
  end,
  themes = {
    {
      name = "Sonokai Default",
      colorscheme = "sonokai",
      before = [[vim.g.sonokai_style = "default"]],
    },
    {
      name = "Sonokai Atlantis",
      colorscheme = "sonokai",
      before = [[vim.g.sonokai_style = "atlantis"]],
    },
    {
      name = "Sonokai Andromeda",
      colorscheme = "sonokai",
      before = [[vim.g.sonokai_style = "andromeda"]],
    },
    {
      name = "Sonokai Shusia",
      colorscheme = "sonokai",
      before = [[vim.g.sonokai_style = "shusia"]],
    },
    {
      name = "Sonokai Maia",
      colorscheme = "sonokai",
      before = [[vim.g.sonokai_style = "maia"]],
    },
    {
      name = "Sonokai Espresso",
      colorscheme = "sonokai",
      before = [[vim.g.sonokai_style = "espresso"]],
    },
  },
}
