require("lib.tools").check("sql", {
  { name = "sql-formatter", bin = "sql-formatter", kind = "fmt" },
})

return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        sql = { "sql_formatter" },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "sql" } },
  },
}
