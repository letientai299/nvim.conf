return {
  cmd = { "yaml-language-server", "--stdio" },
  filetypes = { "yaml", "yaml.docker-compose" },
  root_markers = { ".git" },
  settings = {
    yaml = {
      schemaStore = { enable = false, url = "" },
      customTags = { "!reference sequence" },
      schemas = {
        ["https://gitlab.com/gitlab-org/gitlab-foss/-/raw/master/app/assets/javascripts/editor/schema/ci.json"] = {
          "**/.gitlab-ci.yml",
          "**/.gitlab-ci.yaml",
          "**/*.gitlab-ci.yml",
          "**/*.gitlab-ci.yaml",
          "**/.gitlab/ci/**/*.yml",
          "**/.gitlab/ci/**/*.yaml",
        },
        ["https://www.schemastore.org/github-workflow.json"] = {
          "**/.github/workflows/*.yml",
          "**/.github/workflows/*.yaml",
        },
        ["https://www.schemastore.org/github-action.json"] = {
          "**/action.yml",
          "**/action.yaml",
          "**/.github/actions/**/action.yml",
          "**/.github/actions/**/action.yaml",
        },
      },
    },
  },
  on_init = function(client)
    require("lib.lazy_ondemand").on_load("SchemaStore.nvim", function()
      if client:is_stopped() then
        return
      end
      local schemas = require("schemastore").yaml.schemas()
      for url, patterns in pairs(client.settings.yaml.schemas) do
        schemas[url] = vim.fn.uniq(
          vim.fn.sort(vim.list_extend(schemas[url] or {}, patterns))
        )
      end
      client.settings.yaml.schemas = schemas
      client:notify("workspace/didChangeConfiguration", {
        settings = client.settings,
      })
    end)
    require("lazy").load({ plugins = { "SchemaStore.nvim" } })
  end,
}
