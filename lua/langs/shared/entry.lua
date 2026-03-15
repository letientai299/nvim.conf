local M = {}

local initialized = {}

local function listify(value)
  if value == nil then
    return {}
  end
  if type(value) == "table" then
    return value
  end
  return { value }
end

--- Register one-time language state, then configure the current buffer.
--- Pass `bufnr = nil` to run only the one-time setup path (formatter defs,
--- formatter/linter registry entries, and `once()` hooks). Generated lazy
--- formatter loaders use that mode.
---@param key string
---@param bufnr integer|nil
---@param opts table
function M.setup(key, bufnr, opts)
  if not initialized[key] then
    initialized[key] = true

    local registry = require("lib.lang_registry")

    if opts.formatter_defs then
      for name, config in pairs(opts.formatter_defs) do
        registry.add_formatter(name, config)
      end
    end

    if opts.formatters then
      registry.add_formatters(
        opts.formatter_fts or opts.filetypes or key,
        opts.formatters
      )
    end

    if opts.linters then
      registry.add_linter(
        opts.linter_fts or opts.filetypes or key,
        opts.linters
      )
    end

    if opts.once then
      opts.once()
    end
  end

  local function setup_buffer()
    for _, name in ipairs(listify(opts.lsps or opts.lsp)) do
      require("lib.lsp").enable(name, bufnr)
    end

    if opts.each then
      opts.each(bufnr)
    end

    if opts.tools then
      require("lib.tools").ensure(opts.tools, function()
        if not vim.api.nvim_buf_is_valid(bufnr) then
          return
        end
        -- Retry after tool installs; the first enable may have run before the
        -- server binary existed on PATH.
        for _, name in ipairs(listify(opts.lsps or opts.lsp)) do
          require("lib.lsp").enable(name, bufnr)
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
          if vim.api.nvim_buf_is_valid(bufnr) then
            setup_buffer()
          end
        end,
      })
      return
    end

    setup_buffer()
  end
end

return M
