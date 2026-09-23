-- LSP defaults live in lib.lsp and are applied on first enable so the cold
-- startup path does not need to load vim.lsp up front.

vim.api.nvim_create_user_command("LspInfo", function()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if #clients == 0 then
    vim.notify("No LSP clients attached", vim.log.levels.WARN)
    return
  end

  local cap_names = {
    { "completionProvider", "completion" },
    { "hoverProvider", "hover" },
    { "definitionProvider", "definition" },
    { "referencesProvider", "references" },
    { "renameProvider", "rename" },
    { "documentFormattingProvider", "format" },
    { "codeActionProvider", "codeAction" },
    { "signatureHelpProvider", "signature" },
    { "inlayHintProvider", "inlayHint" },
  }

  local lines = { "buf ft: " .. vim.bo.filetype, "" }
  for _, c in ipairs(clients) do
    local status = c.initialized and "ready" or "initializing"
    table.insert(lines, string.format("%s (id=%d, %s)", c.name, c.id, status))
    table.insert(lines, "  root: " .. (c.root_dir or "none"))
    local cmd = c.config.cmd
    local cmd_text = type(cmd) == "table" and table.concat(cmd, " ")
      or type(cmd) == "function" and "<function>"
      or tostring(cmd or "")
    table.insert(lines, "  cmd:  " .. cmd_text)
    table.insert(
      lines,
      "  ft:   " .. table.concat(c.config.filetypes or {}, ", ")
    )
    local caps = {}
    for _, pair in ipairs(cap_names) do
      if c.server_capabilities[pair[1]] then
        table.insert(caps, pair[2])
      end
    end
    table.insert(lines, "  caps: " .. (table.concat(caps, ", ")))
    table.insert(lines, "")
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end, { desc = "Show LSP clients attached to current buffer" })

vim.api.nvim_create_user_command("LspRestart", function()
  local clients = vim.lsp.get_clients()
  if #clients == 0 then
    vim.notify("No LSP clients running", vim.log.levels.WARN)
    return
  end

  local names = {}
  for _, c in ipairs(clients) do
    table.insert(names, c.name)
    c:stop(true)
  end

  -- Re-fire the nvim.lsp.enable FileType autocmd once every client exited
  local tries = 0
  local function reattach()
    if next(vim.lsp.get_clients()) and tries < 50 then
      tries = tries + 1
      vim.defer_fn(reattach, 100)
      return
    end
    vim.cmd.doautoall("nvim.lsp.enable FileType")
    vim.notify(
      "LSP restarted: " .. table.concat(names, ", "),
      vim.log.levels.INFO
    )
  end
  vim.defer_fn(reattach, 100)
end, { desc = "Force restart all LSP clients" })

return {}
