vim.lsp.config("*", {
  root_markers = { ".git" },
  capabilities = require("blink.cmp").get_lsp_capabilities(),
})

vim.api.nvim_create_user_command("LspInfo", function()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if #clients == 0 then
    vim.notify("No LSP clients attached", vim.log.levels.WARN)
    return
  end
  local lines = {}
  for _, c in ipairs(clients) do
    table.insert(lines, string.format("**%s** (id=%d)", c.name, c.id))
    table.insert(lines, string.format("  root: %s", c.root_dir or "none"))
    table.insert(
      lines,
      string.format("  cmd:  %s", table.concat(c.config.cmd or {}, " "))
    )
    table.insert(
      lines,
      string.format("  ft:   %s", table.concat(c.config.filetypes or {}, ", "))
    )
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end, { desc = "Show LSP clients attached to current buffer" })

return {}
