local M = {}

local fallback_config = vim.fn.stdpath("config") .. "/rumdl.toml"

--- Check if a project-level rumdl config exists near `path`.
--- When present, the project controls its own rules — our defaults don't apply.
--- @param path string
--- @return boolean
local function has_project_config(path)
  local root = vim.fs.root(path, ".git")
  local stop = root or vim.env.HOME
  if
    #vim.fs.find({ ".rumdl.toml", "rumdl.toml" }, {
      path = path,
      upward = true,
      stop = stop,
      type = "file",
      limit = 1,
    }) > 0
  then
    return true
  end
  return root ~= nil and vim.uv.fs_stat(root .. "/.config/rumdl.toml") ~= nil
end

--- Build rumdl CLI flags that apply the fallback config when needed.
--- @param path string file or directory to check for project config
--- @return string[]
local function fallback_flags(path)
  if has_project_config(path) then
    return {}
  end
  return { "--no-config", "--config", fallback_config }
end

function M.markdown(bufnr)
  require("langs.shared.entry").setup("markdown", bufnr, {
    tools = {
      { name = "marksman", bin = "marksman", kind = "lsp" },
      require("lib.prettier").tool(),
      { name = "rumdl", bin = "rumdl", kind = "lsp" },
    },
    lsp = { "marksman", "rumdl" },
    formatter_fts = { "markdown", "markdown.mdx" },
    formatter_defs = {
      rumdl_fix = {
        command = "rumdl",
        args = function(_, ctx)
          local args = { "check", "--fix" }
          vim.list_extend(args, fallback_flags(ctx.dirname))
          vim.list_extend(args, { "--", "$FILENAME" })
          return args
        end,
        stdin = false,
      },
    },
    formatters = { "rumdl_fix", "prettier" },
    parsers = { "markdown", "markdown_inline" },
    once = function()
      local path = bufnr and vim.api.nvim_buf_get_name(bufnr) or ""
      local flags = fallback_flags(path)
      if #flags > 0 then
        local cmd = { "rumdl", "server", "--stdio" }
        vim.list_extend(cmd, flags)
        vim.lsp.config("rumdl", { cmd = cmd })
      end
    end,
  })
end

function M.mdx(bufnr)
  require("langs.shared.entry").setup("mdx", bufnr, {
    tools = {
      {
        name = "mdx-language-server",
        bin = "mdx-language-server",
        kind = "lsp",
      },
      require("lib.prettier").tool(),
    },
    lsp = "mdx_analyzer",
    formatter_fts = "mdx",
    formatters = { "prettier" },
    parsers = { "markdown", "markdown_inline" },
    once = function()
      vim.treesitter.language.register("markdown", "mdx")
    end,
  })
end

return M
