return {
  "glacambre/firenvim",
  lazy = not vim.g.started_by_firenvim,
  build = ":call firenvim#install(0)",
  init = function()
    if not vim.g.started_by_firenvim then
      return
    end

    local font = require("store-guifont").new("firenvim")

    -- Minimal UI — set early so the window doesn't flash with bars.
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

    -- Re-apply after VeryLazy so lualine doesn't override.
    -- Defer lines/columns to avoid racing firenvim's grid_resize
    -- (see glacambre/firenvim#800).
    vim.api.nvim_create_autocmd("User", {
      pattern = "VeryLazy",
      callback = function()
        vim.o.laststatus = 0
        vim.o.showtabline = 0
        font:apply("JetBrainsMono Nerd Font Mono:h11")
        vim.defer_fn(function()
          vim.o.lines = 20
          vim.o.columns = 80
        end, 200)
      end,
    })

    font:map_pick()
    font:map_zoom()
  end,
}
