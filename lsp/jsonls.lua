return {
  cmd = { "vscode-json-languageserver", "--stdio" },
  filetypes = { "json", "jsonc" },
  root_markers = { ".git" },
  settings = {
    json = {
      validate = { enable = true },
    },
  },
  on_init = function(client)
    local ok, schemastore = pcall(require, "schemastore")
    if ok then
      client.settings.json.schemas = schemastore.json.schemas()
      client:notify("workspace/didChangeConfiguration", {
        settings = client.settings,
      })
    end
  end,
}
