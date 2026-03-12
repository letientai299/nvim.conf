local is_nested = vim.env.NVIM ~= nil

return {
  "brianhuster/unnest.nvim",
  lazy = not is_nested,
  cmd = is_nested and nil or "UnnestEdit",
  init = function()
    vim.env.VISUAL = vim.v.progpath
    vim.env.EDITOR = vim.v.progpath
    vim.env.MANPAGER = vim.v.progpath .. " +Man!"
  end,
}
