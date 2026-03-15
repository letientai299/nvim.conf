local specs = require("plugins.themes.catalog").load_specs()
specs[#specs + 1] = {
  dir = vim.fn.stdpath("config") .. "/plugins/store-theme",
  name = "store-theme",
  cmd = "ThemeSave",
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
