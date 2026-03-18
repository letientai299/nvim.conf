local function clear_virtcolumn()
  vim.b.virtcolumn_items = {}
  vim.w.virtcolumn_items = {}
  local ns = vim.api.nvim_create_namespace("virtcolumn")
  vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
end

return {
  "echasnovski/mini.starter",
  lazy = true,
  cmd = "MiniStarter",
  event = "VeryLazy",
  config = function(_, opts)
    require("mini.starter").setup(opts)
    vim.api.nvim_create_user_command("MiniStarter", function()
      require("mini.starter").open()
      clear_virtcolumn()
    end, {})
  end,
  init = function()
    -- mini.starter's autoopen fires on VimEnter, but we load on VeryLazy
    -- (after VimEnter). Manually open on empty starts.
    if vim.fn.argc(-1) == 0 and not vim.env.NVIM_PAGER then
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        once = true,
        callback = function()
          local ok, starter = pcall(require, "mini.starter")
          if ok then
            starter.open()
            clear_virtcolumn()
          end
        end,
      })
    end
  end,
  opts = function()
    local starter = require("mini.starter")
    return {
      autoopen = false, -- we handle open manually in init
      footer = "",
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
