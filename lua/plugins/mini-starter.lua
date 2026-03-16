return {
  "echasnovski/mini.starter",
  lazy = true,
  event = "VeryLazy",
  init = function()
    -- mini.starter's autoopen fires on VimEnter, but we load on VeryLazy
    -- (after VimEnter). Manually open on empty starts.
    if vim.fn.argc(-1) == 0 then
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        once = true,
        callback = function()
          pcall(require("mini.starter").open)
        end,
      })
    end
  end,
  opts = function()
    local starter = require("mini.starter")
    return {
      autoopen = false, -- we handle open manually in init
      items = {
        starter.sections.recent_files(10, true, true),
        starter.sections.recent_files(10, false, true),
        { name = "Quit", action = "qa", section = "Actions" },
      },
      content_hooks = {
        starter.gen_hook.aligning("center", "center"),
      },
    }
  end,
}
