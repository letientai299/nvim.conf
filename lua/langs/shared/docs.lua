local M = {}

local fc = require("lib.fallback_config")
local rumdl = require("lib.rumdl")

function M.markdown(bufnr)
  require("langs.shared.entry").setup("markdown", bufnr, {
    tools = {
      { bin = "marksman", kind = "lsp", mise = "marksman" },
      require("lib.prettier").tool(),
      rumdl.tool(),
    },
    lsp = { "marksman", "rumdl" },
    formatter_fts = { "markdown", "markdown.mdx" },
    formatter_defs = {
      rumdl_fix = {
        command = "rumdl",
        args = function(_, ctx)
          local args = { "check", "--fix", "--fail-on", "never" }
          vim.list_extend(args, fc.flags(rumdl.fallback_spec, ctx.dirname))
          vim.list_extend(args, { "--", "$FILENAME" })
          return args
        end,
        stdin = false,
      },
    },
    formatters = { "rumdl_fix", "prettier" },
  })
end

function M.mdx(bufnr)
  require("langs.shared.entry").setup("mdx", bufnr, {
    tools = {
      {
        bin = "mdx-language-server",
        kind = "lsp",
        mise = "npm:@mdx-js/language-server",
      },
      require("lib.prettier").tool(),
    },
    lsp = "mdx_analyzer",
    formatter_fts = "mdx",
    formatters = { "prettier" },
    once = function()
      vim.treesitter.language.register("markdown", "mdx")
    end,
  })
end

return M
