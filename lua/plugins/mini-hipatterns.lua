return {
  "echasnovski/mini.hipatterns",
  event = "VeryLazy",
  opts = function()
    local hipatterns = require("mini.hipatterns")
    return {
      highlighters = {
        hex_color = hipatterns.gen_highlighter.hex_color(),
      },
    }
  end,
}
