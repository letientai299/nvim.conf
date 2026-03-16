return {
  "nvim-mini/mini.indentscope",
  event = "VeryLazy",
  config = function(_, opts)
    -- Disable on the dashboard buffer that already exists before this plugin loads
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buf].filetype == "ministarter" then
        vim.b[buf].miniindentscope_disable = true
      end
    end
    require("mini.indentscope").setup(opts)
  end,
  opts = function()
    return {
      symbol = "│",
      draw = {
        delay = 50,
        animation = require("mini.indentscope").gen_animation.quadratic({
          easing = "out",
          duration = 50,
          unit = "total",
        }),
      },
    }
  end,
}
