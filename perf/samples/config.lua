-- Neovim plugin configuration (lazy.nvim style)
-- Exercises: tables, strings, functions, conditionals, vim API

local M = {}

---@class PluginConfig
---@field colorscheme string
---@field icons boolean
---@field diagnostics table
---@field completion table
---@field keymaps table<string, string|function>

---@type PluginConfig
local defaults = {
  colorscheme = "catppuccin",
  icons = true,
  diagnostics = {
    virtual_text = { prefix = "●", spacing = 4 },
    signs = true,
    underline = true,
    severity_sort = true,
    float = { border = "rounded", source = "if_many" },
  },
  completion = {
    sources = { "lsp", "buffer", "path", "snippets" },
    max_items = 20,
    preselect = true,
    ghost_text = false,
  },
  keymaps = {},
}

local function deep_merge(base, override)
  local result = {}
  for k, v in pairs(base) do
    if type(v) == "table" and type(override[k]) == "table" then
      result[k] = deep_merge(v, override[k])
    elseif override[k] ~= nil then
      result[k] = override[k]
    else
      result[k] = v
    end
  end
  for k, v in pairs(override) do
    if result[k] == nil then
      result[k] = v
    end
  end
  return result
end

---@param opts PluginConfig|nil
function M.setup(opts)
  local config = deep_merge(defaults, opts or {})

  -- Diagnostics
  vim.diagnostic.config(config.diagnostics)

  local signs = {
    Error = " ",
    Warn = " ",
    Hint = "󰌵 ",
    Info = " ",
  }
  for severity, icon in pairs(signs) do
    local hl = "DiagnosticSign" .. severity
    vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
  end

  -- Colorscheme
  local ok, _ = pcall(vim.cmd.colorscheme, config.colorscheme)
  if not ok then
    vim.notify(
      string.format(
        "Colorscheme '%s' not found, falling back to default",
        config.colorscheme
      ),
      vim.log.levels.WARN
    )
  end

  -- Keymaps
  local map = vim.keymap.set
  local default_keymaps = {
    ["<leader>e"] = { vim.diagnostic.open_float, "Show diagnostics" },
    ["[d"] = { vim.diagnostic.goto_prev, "Previous diagnostic" },
    ["]d"] = { vim.diagnostic.goto_next, "Next diagnostic" },
    ["<leader>q"] = { vim.diagnostic.setloclist, "Diagnostics to loclist" },
  }

  for lhs, rhs in pairs(default_keymaps) do
    if not config.keymaps[lhs] then
      map("n", lhs, rhs[1], { desc = rhs[2] })
    end
  end

  for lhs, rhs in pairs(config.keymaps) do
    if type(rhs) == "string" then
      map("n", lhs, rhs, { desc = rhs })
    elseif type(rhs) == "function" then
      map("n", lhs, rhs, {})
    end
  end

  -- Autocommands
  local group = vim.api.nvim_create_augroup("UserConfig", { clear = true })

  vim.api.nvim_create_autocmd("TextYankPost", {
    group = group,
    callback = function()
      vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
    end,
  })

  vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    callback = function(ev)
      local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
      local line_count = vim.api.nvim_buf_line_count(ev.buf)
      if mark[1] > 0 and mark[1] <= line_count then
        pcall(vim.api.nvim_win_set_cursor, 0, mark)
      end
    end,
  })

  return config
end

return M
