local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("env", bufnr, {
    tools = {
      { bin = "dotenv-linter", mise = "dotenv-linter" },
    },
    linters = { "dotenv_linter" },
    once = function()
      -- Skip style checks that fire on grouped, human-ordered env files.
      require("lib.lazy_ondemand").on_load("nvim-lint", function()
        local linter = require("lint").linters.dotenv_linter
        linter.args = {
          "check",
          "--quiet",
          "--skip",
          "UnorderedKey",
          "--skip",
          "ExtraBlankLine",
        }
      end)
    end,
  })
end

return M
