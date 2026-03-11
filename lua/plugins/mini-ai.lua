return {
  "echasnovski/mini.ai",
  dependencies = { { "nvim-treesitter/nvim-treesitter-textobjects", branch = "main" } },
  lazy = false,
  opts = {
    -- Search the whole buffer; default 50 breaks large classes (C#, Java).
    n_lines = math.huge,
    -- Remap *_last to `L` so `il`/`al` work as textobject `l` (line).
    mappings = {
      around_last = "aL",
      inside_last = "iL",
    },
    custom_textobjects = require("textobjects"),
  },
}
