return {
  "nvim-mini/mini.indentscope",
  event = "VeryLazy",
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
