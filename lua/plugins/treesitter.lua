return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local group =
      vim.api.nvim_create_augroup("UserTreesitter", { clear = true })

    require("lib.treesitter").register_default_languages()
    require("nvim-treesitter").setup({})

    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      callback = function(args)
        if vim.bo[args.buf].buftype ~= "" then
          vim.b[args.buf].ts_highlight = false
          return
        end

        local lib_ts = require("lib.treesitter")
        if lib_ts.enable_highlight(args.buf) then
          return
        end

        -- Parser missing — try to auto-install it
        lib_ts.auto_install(args.buf)
      end,
    })
  end,
}
