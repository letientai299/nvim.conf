return {
  "tiagovla/scope.nvim",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    require("scope").setup()
  end,
}
