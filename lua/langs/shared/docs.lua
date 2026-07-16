local M = {}

local fc = require("lib.fallback_config")
local rumdl = require("lib.rumdl")

function M.markdown(bufnr)
  require("langs.shared.entry").setup("markdown", bufnr, {
    tools = {
      { bin = "marksman", mise = "marksman" },
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

  -- :Md2cb — convert the whole buffer (or the visual selection) to rich text
  -- and put it on the clipboard via the `md2cb` CLI, for pasting into Teams,
  -- Slack, docs, etc. https://github.com/letientai299/md2cb
  vim.api.nvim_buf_create_user_command(bufnr, "Md2cb", function(opts)
    local first, last = 0, -1
    if opts.range > 0 then
      first, last = opts.line1 - 1, opts.line2
    end
    local text =
      table.concat(vim.api.nvim_buf_get_lines(bufnr, first, last, false), "\n")
    vim.system({ "md2cb" }, { stdin = text }, function(result)
      vim.schedule(function()
        if result.code == 0 then
          vim.notify(
            "md2cb: rich text copied to clipboard",
            vim.log.levels.INFO
          )
        else
          local msg = result.stderr and result.stderr:gsub("%s+$", "") or ""
          vim.notify("md2cb failed: " .. msg, vim.log.levels.ERROR)
        end
      end)
    end)
  end, {
    range = true,
    desc = "Convert markdown (buffer or selection) to rich text clipboard via md2cb",
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
