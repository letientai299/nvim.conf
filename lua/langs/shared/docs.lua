local M = {}

-- stylua: ignore
local disabled_rules = {
  "MD013", -- line-length: prettier handles wrapping
  "MD024", -- no-duplicate-heading: same heading in different sections is valid
  "MD033", -- no-inline-html: needed for <details>, <kbd>, etc.
  "MD041", -- first-line-h1: not all files start with h1
  "MD034", -- no-bare-urls: false positive on multi-line reference link definitions
  "MD053", -- link-image-reference-definitions: false positives with footnotes
}

local disable_csv = table.concat(disabled_rules, ",")

--- Check if a project-level rumdl config exists near `path`.
--- When present, the project controls its own rules — our defaults don't apply.
--- Checks .rumdl.toml, rumdl.toml (upward walk), and .config/rumdl.toml at root.
--- pyproject.toml ([tool.rumdl]) is not checked — requires reading file contents.
local function has_project_config(path)
  local root = vim.fs.root(path, ".git")
  local stop = root or vim.env.HOME
  -- Standard config files found via upward walk
  local found = vim.fs.find({ ".rumdl.toml", "rumdl.toml" }, {
    path = path,
    upward = true,
    stop = stop,
    type = "file",
    limit = 1,
  })
  if #found > 0 then
    return true
  end
  -- .config/rumdl.toml at the project root (not in upward walk — nested path)
  if root then
    return vim.uv.fs_stat(root .. "/.config/rumdl.toml") ~= nil
  end
  return false
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
          local base = { "check", "--fix" }
          if not has_project_config(ctx.dirname) then
            vim.list_extend(base, { "--disable", disable_csv })
          end
          vim.list_extend(base, { "--", "$FILENAME" })
          return base
        end,
        stdin = false,
      },
    },
    formatters = { "rumdl_fix", "prettier" },
    parsers = { "markdown", "markdown_inline" },
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
