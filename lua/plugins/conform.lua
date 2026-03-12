return {
  "stevearc/conform.nvim",
  event = "BufWritePre",
  cmd = "ConformInfo",
  ---@module "conform"
  ---@type conform.setupOpts
  opts = {
    formatters_by_ft = {
      -- Runs on all filetypes, after per-ft formatters.
      -- Does NOT run when LSP fallback is used (lsp_format = "fallback"
      -- only triggers when no per-ft conform formatters are configured).
      ["*"] = { "trim_whitespace", "trim_newlines", "injected" },
    },
    default_format_opts = {
      lsp_format = "fallback",
    },
    format_on_save = {
      timeout_ms = 500,
    },
  },
  init = function()
    vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
  end,
}
