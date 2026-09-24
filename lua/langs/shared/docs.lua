local M = {}

local fc = require("lib.fallback_config")
local rumdl = require("lib.rumdl")

local function is_marimo(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    if
      line:match("^marimo%-version:%s*")
      or line:match("^```.*{[^}]*%.?marimo[^}]*}")
    then
      return true
    end
  end

  return false
end

local function setup_marimo(bufnr)
  if not is_marimo(bufnr) then
    return
  end

  local ondemand = require("lib.lazy_ondemand")
  ondemand.on_load("otter.nvim", function()
    if is_marimo(bufnr) then
      vim.api.nvim_buf_call(bufnr, function()
        require("otter").activate({ "python" }, true, true)
      end)
    end
  end)
  require("lazy").load({ plugins = { "otter.nvim" } })
end

function M.markdown(bufnr)
  require("langs.shared.entry").setup("markdown", bufnr, {
    tools = {
      { bin = "marksman", mise = "marksman" },
      require("lib.prettier").tool(),
      rumdl.tool(),
    },
    lsp = { "marksman", "rumdl" },
    formatter_fts = { "markdown", "markdown.mdx", "quarto" },
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
    formatters = { "prettier", "rumdl_fix" },
  })

  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  setup_marimo(bufnr)

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
