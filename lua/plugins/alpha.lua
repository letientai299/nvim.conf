return {
  "goolord/alpha-nvim",
  event = "VimEnter",
  config = function()
    if vim.fn.argc() > 0 or vim.bo.buftype ~= "" or vim.fn.line("$") ~= 1 or vim.fn.getline(1) ~= "" then
      return
    end

    local alpha = require("alpha")
    local cfg = require("alpha.themes.startify")
    cfg.section.header.val = {}
    alpha.setup(cfg.config)
    -- Unlist the empty startup buffer so it doesn't show in bufferline.
    vim.bo.buflisted = false
    alpha.start(false)
  end,
}
