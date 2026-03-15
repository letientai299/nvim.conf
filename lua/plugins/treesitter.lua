return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local group =
      vim.api.nvim_create_augroup("UserTreesitter", { clear = true })

    require("lib.treesitter").register_default_languages()
    -- Explicitly pass install_dir so nvim-treesitter adds it to rtp.
    -- lazy.nvim strips the default stdpath("data")/site from rtp.
    require("nvim-treesitter").setup({
      install_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site"),
    })

    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      callback = function(args)
        if vim.bo[args.buf].buftype ~= "" then
          vim.b[args.buf].ts_highlight = false
          return
        end

        local function apply()
          if not vim.api.nvim_buf_is_valid(args.buf) then
            return
          end
          local lib_ts = require("lib.treesitter")
          if lib_ts.enable_highlight(args.buf) then
            return
          end
          lib_ts.auto_install(args.buf)
        end

        -- Defer query compilation during cold startup so first redraw isn't blocked
        if vim.v.vim_did_enter == 0 then
          vim.schedule(apply)
        else
          apply()
        end
      end,
    })
  end,
}
