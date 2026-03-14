return {
  "nvim-mini/mini.ai",
  keys = {
    { "a", mode = { "o", "x" } },
    { "i", mode = { "o", "x" } },
  },
  opts = function()
    return {
      -- Search the whole buffer; default 50 breaks large classes (C#, Java).
      n_lines = math.huge,
      -- Remap *_last to `L` so `il`/`al` work as textobject `l` (line).
      mappings = {
        around_last = "aL",
        inside_last = "iL",
      },
      custom_textobjects = require("textobjects"),
    }
  end,
}
