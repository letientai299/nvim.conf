return {
  "sainnhe/gruvbox-material",
  lazy = true,
  init_globals = {
    gruvbox_material_loaded_file_types = {},
  },
  init = function()
    vim.g.gruvbox_material_enable_italic = 1
    vim.g.gruvbox_material_enable_bold = 1
    vim.g.gruvbox_material_dim_inactive_windows = 1
    vim.g.gruvbox_material_better_performance = 1
  end,
  themes = {
    {
      name = "Gruvbox Material Dark",
      colorscheme = "gruvbox-material",
      before = [[
        vim.opt.background = "dark"
        vim.g.gruvbox_material_foreground = "material"
      ]],
    },
    {
      name = "Gruvbox Material Mix Dark",
      colorscheme = "gruvbox-material",
      before = [[
        vim.opt.background = "dark"
        vim.g.gruvbox_material_foreground = "mix"
      ]],
    },
    {
      name = "Gruvbox Material Original Dark",
      colorscheme = "gruvbox-material",
      before = [[
        vim.opt.background = "dark"
        vim.g.gruvbox_material_foreground = "original"
      ]],
    },
    {
      name = "Gruvbox Material Light",
      colorscheme = "gruvbox-material",
      before = [[
        vim.opt.background = "light"
        vim.g.gruvbox_material_foreground = "material"
      ]],
    },
  },
}
