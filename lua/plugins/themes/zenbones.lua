return {
  "mcchrish/zenbones.nvim",
  dependencies = { "rktjmp/lush.nvim" },
  lazy = true,
  init = function()
    vim.g.zenbones_darken_comments = 45
  end,
  themes = {
    "zenbones",
    "zenwritten",
    "neobones",
    "vimbones",
    "rosebones",
    "forestbones",
    "nordbones",
    "tokyobones",
    "seoulbones",
    "duckbones",
    "zenburned",
    "kanagawabones",
  },
}
