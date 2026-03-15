local M = {}

local fc = require("lib.fallback_config")
local rumdl_spec = {
  names = { ".rumdl.toml", "rumdl.toml" },
  flag = "--config",
  fallback = vim.fn.stdpath("config") .. "/configs/rumdl.toml",
  extra_dirs = { ".config" },
}

function M.markdown(bufnr)
  require("langs.shared.entry").setup("markdown", bufnr, {
    tools = {
      { bin = "marksman", kind = "lsp", mise = "marksman" },
      require("lib.prettier").tool(),
      { bin = "rumdl", kind = "lsp", mise = "rumdl" },
    },
    lsp = { "marksman", "rumdl" },
    formatter_fts = { "markdown", "markdown.mdx" },
    formatter_defs = {
      rumdl_fix = {
        command = "rumdl",
        args = function(_, ctx)
          local args = { "check", "--fix", "--fail-on", "never" }
          vim.list_extend(args, fc.flags(rumdl_spec, ctx.dirname))
          vim.list_extend(args, { "--", "$FILENAME" })
          return args
        end,
        stdin = false,
      },
    },
    formatters = { "rumdl_fix", "prettier" },
    each = function(buf)
      local path = vim.api.nvim_buf_get_name(buf)
      if path == "" then
        return
      end
      local root = vim.fs.root(path, ".git") or ""
      if root == M._rumdl_root then
        return
      end
      M._rumdl_root = root
      local flags = fc.flags(rumdl_spec, path)
      local cmd = { "rumdl", "server", "--stdio" }
      vim.list_extend(cmd, flags)
      vim.lsp.config("rumdl", { cmd = cmd })
    end,
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
