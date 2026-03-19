local M = {}

local initialized = {}
local once_ran = {}

local function listify(value)
  if value == nil then
    return {}
  end
  if type(value) == "table" then
    return value
  end
  return { value }
end

local function resolve(value)
  if type(value) == "function" then
    return value()
  end
  return value
end

--- Register one-time language state, then configure the current buffer.
--- Pass `bufnr = nil` to run only the one-time setup path (formatter defs,
--- formatter/linter registry entries, and `once()` hooks). Generated lazy
--- formatter loaders use that mode.
---@param key string
---@param bufnr integer|nil
---@param opts table
function M.setup(key, bufnr, opts)
  -- Otter companion buffers (e.g. file.md.otter.ts) get filetype set by otter,
  -- which triggers ftplugin loading. Skip our setup — otter manages LSP for
  -- these buffers internally, and vim.lsp.enable's doautoall chokes on them.
  if bufnr then
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name:find("%.otter%.") then
      return
    end
  end

  if opts.once and not once_ran[key] then
    once_ran[key] = true
    opts.once()
  end

  local function init_language()
    if initialized[key] then
      return
    end

    initialized[key] = true
    local registry = require("lib.lang_registry")
    local formatter_defs = resolve(opts.formatter_defs)
    local formatters = resolve(opts.formatters)
    local linters = resolve(opts.linters)
    local formatter_fts = resolve(opts.formatter_fts or opts.filetypes) or key
    local linter_fts = resolve(opts.linter_fts or opts.filetypes) or key

    if formatter_defs then
      for name, config in pairs(formatter_defs) do
        registry.add_formatter(name, config)
      end
    end

    if formatters then
      registry.add_formatters(formatter_fts, formatters)
    end

    if linters then
      registry.add_linter(linter_fts, linters)
    end
  end

  local function setup_buffer()
    local lsps = listify(resolve(opts.lsps or opts.lsp))
    local tools = resolve(opts.tools)
    local lsp = require("lib.lsp")

    for _, name in ipairs(lsps) do
      lsp.enable_until_ready(name, bufnr)
    end

    if opts.each then
      opts.each(bufnr)
    end

    if tools then
      require("tool-installer").ensure(tools, function()
        if not vim.api.nvim_buf_is_valid(bufnr) then
          return
        end
        -- Retry after tool installs; the first enable may have run before the
        -- server binary existed on PATH.
        for _, name in ipairs(lsps) do
          lsp.enable_until_ready(name, bufnr)
        end
      end)
    end
  end

  if bufnr then
    if vim.v.vim_did_enter == 0 then
      -- During startup, defer buffer-local work until VeryLazy so the cold path
      -- stays light. If the buffer vanishes before then, reopening it will
      -- retry through FileType.
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        once = true,
        callback = function()
          init_language()
          if vim.api.nvim_buf_is_valid(bufnr) then
            setup_buffer()
          end
        end,
      })
      return
    end

    init_language()
    setup_buffer()
    return
  end

  init_language()
end

return M
