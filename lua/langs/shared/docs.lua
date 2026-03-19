local M = {}

local fc = require("lib.fallback_config")
local ondemand = require("lib.lazy_ondemand")
local rumdl = require("lib.rumdl")

local function activate_otter(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.api.nvim_buf_call(buf, function()
    require("otter").activate()
  end)
end

function M.markdown(bufnr)
  require("langs.shared.entry").setup("markdown", bufnr, {
    tools = {
      { bin = "marksman", mise = "marksman" },
      require("lib.prettier").tool(),
      rumdl.tool(),
    },
    lsp = { "marksman", "rumdl" },
    each = function(buf)
      if package.loaded["otter"] then
        activate_otter(buf)
      else
        ondemand.on_load("otter.nvim", function()
          activate_otter(buf)
        end)
      end
    end,
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
        mise = "npm:@mdx-js/language-server",
        dependencies = { "node" },
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
