return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  event = { "BufReadPre", "BufNewFile" },
  init = function()
    -- Pre-warm treesitter on bare startup (no file args) so the first file
    -- open doesn't pay the ~12ms plugin load penalty. VeryLazy is post-paint.
    if vim.fn.argc(-1) == 0 then
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        once = true,
        callback = function()
          require("lazy").load({ plugins = { "nvim-treesitter" } })
        end,
      })
    end
  end,
  config = function()
    local group =
      vim.api.nvim_create_augroup("UserTreesitter", { clear = true })

    require("lib.treesitter").register_default_languages()
    -- Explicitly pass install_dir so nvim-treesitter adds it to rtp.
    -- lazy.nvim strips the default stdpath("data")/site from rtp, and
    -- setup() re-adds it — but only to the rtp string. If the directory
    -- doesn't exist on disk yet (fresh install, no parsers compiled),
    -- the next lazy.nvim plugin load rebuilds rtp via
    -- nvim_get_runtime_file("", true) which filters non-existent paths,
    -- silently dropping site. Pre-create the directory so it survives.
    local install_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site")
    vim.fn.mkdir(install_dir, "p")
    require("nvim-treesitter").setup({ install_dir = install_dir })

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
