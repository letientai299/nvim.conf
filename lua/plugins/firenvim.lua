return {
  "glacambre/firenvim",
  lazy = not vim.g.started_by_firenvim,
  build = ":call firenvim#install(0)",
  init = function()
    if not vim.g.started_by_firenvim then
      return
    end

    -- Minimal UI for browser embed
    vim.o.laststatus = 0
    vim.o.showtabline = 0
    vim.o.number = false
    vim.o.relativenumber = false
    vim.o.signcolumn = "no"

    vim.g.firenvim_config = {
      globalSettings = { alt = "all" },
      localSettings = {
        [".*"] = {
          cmdline = "neovim",
          takeover = "never",
        },
      },
    }

    -- Fixed frame size — must wait for UIEnter, then defer to avoid race
    -- with firenvim's own grid_resize (see glacambre/firenvim#800).
    vim.api.nvim_create_autocmd("UIEnter", {
      callback = function()
        local client = vim.api.nvim_get_chan_info(vim.v.event.chan).client
        if not client or client.name ~= "Firenvim" then
          return
        end
        vim.defer_fn(function()
          vim.o.lines = 30
          vim.o.columns = 100
        end, 200)
      end,
    })
  end,
}
