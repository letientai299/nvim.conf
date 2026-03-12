-- Hardcoded blink.cmp completion capabilities so servers start with them
-- immediately — no lazy-load dependency, no restart needed.
-- Source: blink.cmp/lua/blink/cmp/sources/lib/init.lua get_lsp_capabilities()
vim.lsp.config("*", {
  capabilities = {
    textDocument = {
      completion = {
        completionItem = {
          snippetSupport = true,
          commitCharactersSupport = false,
          documentationFormat = { "markdown", "plaintext" },
          deprecatedSupport = true,
          preselectSupport = false,
          tagSupport = { valueSet = { 1 } },
          insertReplaceSupport = true,
          resolveSupport = {
            properties = {
              "documentation",
              "detail",
              "additionalTextEdits",
              "command",
              "data",
            },
          },
          insertTextModeSupport = { valueSet = { 1 } },
          labelDetailsSupport = true,
        },
        completionList = {
          itemDefaults = {
            "commitCharacters",
            "editRange",
            "insertTextFormat",
            "insertTextMode",
            "data",
          },
        },
        contextSupport = true,
        insertTextMode = 1,
      },
    },
  },
})

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
    table.insert(lines, "  cmd:  " .. table.concat(c.config.cmd or {}, " "))
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

return {}
