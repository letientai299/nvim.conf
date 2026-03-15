return {
  dir = vim.fn.stdpath("config") .. "/plugins/tool-installer",
  name = "tool-installer",
  lazy = false,
  config = function()
    require("tool-installer").setup({
      script_dir = vim.fn.stdpath("config") .. "/scripts",
      catalog = {
        go = { bin = "go", mise = "go" },
        node = { bin = "node", mise = "node" },
        rust = { bin = "cargo", mise = "rust" },
        dotnet = { bin = "dotnet", mise = "dotnet" },
      },
    })
  end,
}
