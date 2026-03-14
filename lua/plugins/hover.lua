local lazy_require = require("lib.lazy_ondemand").lazy_require

return {
  "lewis6991/hover.nvim",
  keys = {
    {
      "K",
      function()
        lazy_require("hover").open()
      end,
      desc = "Hover",
    },
    {
      "gK",
      function()
        lazy_require("hover").enter()
      end,
      desc = "Hover (enter window)",
    },
  },
  opts = function()
    return {
      providers = {
        "hover.providers.diagnostic",
        "hover.providers.lsp",
        "lib.hover_vimhelp",
        "hover.providers.man",
        "hover.providers.dictionary",
      },
      preview_opts = { border = "rounded", max_width = 80, wrap = true },
      title = true,
    }
  end,
}
