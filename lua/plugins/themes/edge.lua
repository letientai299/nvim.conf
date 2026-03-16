return {
  "sainnhe/edge",
  lazy = true,
  init_globals = {
    edge_loaded_file_types = {},
  },
  init = function()
    vim.g.edge_enable_italic = 1
    vim.g.edge_dim_inactive_windows = 1
    vim.g.edge_better_performance = 1
  end,
  themes = {
    {
      name = "Edge Dark Default",
      colorscheme = "edge",
      before = [[
        vim.opt.background = "dark"
        vim.g.edge_style = "default"
      ]],
    },
    {
      name = "Edge Dark Aura",
      colorscheme = "edge",
      before = [[
        vim.opt.background = "dark"
        vim.g.edge_style = "aura"
      ]],
    },
    {
      name = "Edge Dark Neon",
      colorscheme = "edge",
      before = [[
        vim.opt.background = "dark"
        vim.g.edge_style = "neon"
      ]],
    },
    {
      name = "Edge Light",
      colorscheme = "edge",
      before = [[vim.opt.background = "light"]],
    },
  },
}
