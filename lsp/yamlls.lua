return {
  cmd = { "yaml-language-server", "--stdio" },
  filetypes = { "yaml", "yaml.docker-compose" },
  root_markers = { ".git" },
  settings = {
    yaml = {
      schemaStore = { enable = false, url = "" },
    },
  },
  on_init = function(client)
    local ok, schemastore = pcall(require, "schemastore")
    if ok then
      client.settings.yaml.schemas = schemastore.yaml.schemas()
      client:notify("workspace/didChangeConfiguration", {
        settings = client.settings,
      })
    end
  end,
}
