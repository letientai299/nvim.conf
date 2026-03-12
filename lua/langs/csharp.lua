local M = {}

function M.setup()
  local registry = require("lib.lang_registry")
  registry.add_formatters("cs", { "csharpier" })
  registry.ensure_parsers({ "c_sharp" })
end

return M
