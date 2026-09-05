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
        -- Plugin pin is v0.21.1 (48b066f), which lacks C++20 module nodes that
        -- current cpp highlight queries require. cuda queries inherit those.
        cuda = {
          install_info = {
            url = "https://github.com/tree-sitter-grammars/tree-sitter-cuda",
            revision = "1ebcedde2e36c4e7fecf79b3119ffeddf5e7a683",
          },
        },
      },
    })
  end,
}
