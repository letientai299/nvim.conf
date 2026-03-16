local theme_helpers = require("lib.theme_helpers")
local specs =
  theme_helpers.prepare_specs(require("plugins.themes.catalog").load_specs())
specs[#specs + 1] = {
  dir = vim.fn.stdpath("config") .. "/plugins/store-theme",
  name = "store-theme",
  keys = {
    {
      "<leader>ft",
      function()
        require("store-theme").pick()
      end,
      desc = "Colorschemes",
    },
  },
}
return specs
