return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  event = "VeryLazy",
  config = function()
    local lib_ts = require("lib.treesitter")
    -- Explicitly pass install_dir so nvim-treesitter adds it to rtp.
    -- lazy.nvim strips the default stdpath("data")/site from rtp, and
    -- setup() re-adds it — but only to the rtp string. If the directory
    -- doesn't exist on disk yet (fresh install, no parsers compiled),
    -- the next lazy.nvim plugin load rebuilds rtp via
    -- nvim_get_runtime_file("", true) which filters non-existent paths,
    -- silently dropping site. Pre-create the directory so it survives.
    local install_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site")
    vim.fn.mkdir(install_dir, "p")
    lib_ts.ensure_runtime()
    require("nvim-treesitter").setup({ install_dir = install_dir })
    require("nvim-treesitter.parsers")
    lib_ts.register_default_languages()
  end,
}
