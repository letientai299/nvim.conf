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
    require("lib.lazy_ondemand").on_load("SchemaStore.nvim", function()
      if client:is_stopped() then
        return
      end
      client.settings.json.schemas = require("schemastore").json.schemas()
      client:notify("workspace/didChangeConfiguration", {
        settings = client.settings,
      })
    end)
    require("lazy").load({ plugins = { "SchemaStore.nvim" } })
  end,
}
