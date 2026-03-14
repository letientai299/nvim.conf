return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    ensure_installed = { "query", "vim", "vimdoc" },
  },
  config = function(_, opts)
    local group =
      vim.api.nvim_create_augroup("UserTreesitter", { clear = true })
    local ts = require("nvim-treesitter")

    require("lib.treesitter").register_default_languages()
    ts.setup({})
    require("lib.lang_registry").activate_treesitter()

    vim.schedule(function()
      ts.install(opts.ensure_installed, { summary = false })
    end)

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
