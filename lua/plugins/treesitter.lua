return {
  "romus204/tree-sitter-manager.nvim",
  event = "VeryLazy",
  config = function()
    local lib_ts = require("lib.treesitter")
    lib_ts.ensure_runtime()
    lib_ts.register_default_languages()

    require("tree-sitter-manager").setup({
      auto_install = true,
      -- We manage highlighting ourselves (destroy patch, syntax clear,
      -- two-phase enable) via lib.treesitter — disable the plugin's built-in.
      highlight = false,
      languages = {
        log = {
          install_info = {
            url = "https://github.com/Tudyx/tree-sitter-log",
            revision = "62cfe307e942af3417171243b599cc7deac5eab9",
          },
        },
      },
    })
  end,
}
