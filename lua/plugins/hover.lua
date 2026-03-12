return {
  "lewis6991/hover.nvim",
  keys = {
    {
      "K",
      function()
        require("hover").open()
      end,
      desc = "Hover",
    },
    {
      "gK",
      function()
        require("hover").enter()
      end,
      desc = "Hover (enter window)",
    },
  },
  opts = {
    providers = {
      "hover.providers.diagnostic",
      "hover.providers.lsp",
      "lib.hover_vimhelp",
      "hover.providers.man",
      "hover.providers.dictionary",
    },
    preview_opts = { border = "rounded", max_width = 80, wrap = true },
    title = true,
  },
}
