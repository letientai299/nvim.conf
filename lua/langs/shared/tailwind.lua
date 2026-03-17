local deferred_lsp = require("langs.shared.deferred_lsp")
local entry = require("langs.shared.entry")

local M = {}

local TAILWIND_DELAY_MS = 1500

function M.setup(bufnr)
  deferred_lsp.schedule(
    bufnr,
    "tailwindcss",
    TAILWIND_DELAY_MS,
    function(buffer)
      entry.setup("tailwind", buffer, {
        tools = {
          {
            bin = "tailwindcss-language-server",
            mise = "npm:tailwindcss-language-server",
            dependencies = { "node" },
          },
        },
        lsp = "tailwindcss",
      })
    end
  )
end

return M
