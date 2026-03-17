local deferred_lsp = require("langs.shared.deferred_lsp")
local entry = require("langs.shared.entry")

local M = {}

local CSSMODULES_DELAY_MS = 1200
local fts = { "javascript", "javascriptreact", "typescript", "typescriptreact" }

local function cssmodules_tool()
  return {
    bin = "cssmodules-language-server",
    mise = "npm:cssmodules-language-server",
    dependencies = { "node" },
  }
end

local function schedule_cssmodules(bufnr)
  deferred_lsp.schedule(
    bufnr,
    "cssmodules_ls",
    CSSMODULES_DELAY_MS,
    function(buffer)
      entry.setup("cssmodules_ls_secondary", buffer, {
        tools = { cssmodules_tool() },
        lsp = "cssmodules_ls",
      })
    end
  )
end

function M.setup(bufnr)
  entry.setup("js_ts", bufnr, {
    tools = function()
      return {
        {
          bin = "vtsls",
          mise = "npm:@vtsls/language-server",
          dependencies = { "node" },
        },
        require("lib.prettier").tool(),
        require("lib.biome").tool(),
      }
    end,
    lsp = "vtsls",
    formatter_fts = fts,
    formatters = { "prettier" },
    linter_fts = fts,
    linters = { "biomejs" },
  })

  schedule_cssmodules(bufnr)
end

return M
