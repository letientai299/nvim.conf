return {
  "glacambre/firenvim",
  lazy = not vim.g.started_by_firenvim,
  cond = vim.g.started_by_firenvim ~= nil,
  build = ":call firenvim#install(0)",
  init = function()
    if not vim.g.started_by_firenvim then
      return
    end

    local font = require("store-guifont").new("firenvim")
    local want = { lines = 16, columns = 100 }

    vim.o.laststatus = 0
    vim.o.showtabline = 0
    vim.o.number = true

    vim.g.firenvim_config = {
      globalSettings = { alt = "all" },
      localSettings = {
        [".*"] = {
          cmdline = "neovim",
          takeover = "never",
          filename = "{hostname}_{pathname%24}_{selector%16}.md",
        },
      },
    }

    local function restore_size()
      if vim.o.lines ~= want.lines or vim.o.columns ~= want.columns then
        vim.o.lines = want.lines
        vim.o.columns = want.columns
      end
    end

    -- Re-apply after VeryLazy so lualine doesn't override statusline/tabline.
    -- Delay lets firenvim's initial resize cascade settle (#800).
    vim.api.nvim_create_autocmd("User", {
      pattern = "VeryLazy",
      callback = function()
        vim.o.laststatus = 0
        vim.o.showtabline = 0
        font:apply("JetBrainsMono Nerd Font Mono:h11")
        vim.defer_fn(restore_size, 100)
      end,
    })

    -- :w syncs text back to the textarea → ResizeObserver → grid resize.
    -- Restore after a delay. Not using VimResized — it creates an
    -- unbreakable async loop across the neovim/browser boundary.
    vim.api.nvim_create_autocmd("BufWritePost", {
      callback = function()
        vim.defer_fn(restore_size, 100)
      end,
    })

    -- Cmd-v paste (macOS) — firenvim doesn't handle <D-v> natively.
    vim.keymap.set({ "i", "c" }, "<D-v>", function()
      local reg = vim.fn.getreg("+")
      if reg ~= "" then
        vim.api.nvim_paste(reg, true, -1)
      end
    end)
    vim.keymap.set("n", "<D-v>", '"+p')

    font:map_pick()
    font:map_zoom()
  end,
}
