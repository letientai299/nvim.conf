local M = {}

function M.setup()
  require("lib.tools").check_now({
    { name = "sql-formatter", bin = "sql-formatter", kind = "fmt" },
  })

  local registry = require("lib.lang_registry")
  registry.add_formatters("sql", { "sql_formatter" })
  registry.ensure_parsers({ "sql" })
end

return M
