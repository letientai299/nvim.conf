local M = {}

local defaults_applied = false

local default_capabilities = {
  textDocument = {
    completion = {
      completionItem = {
        snippetSupport = true,
        commitCharactersSupport = false,
        documentationFormat = { "markdown", "plaintext" },
        deprecatedSupport = true,
        preselectSupport = false,
        tagSupport = { valueSet = { 1 } },
        insertReplaceSupport = true,
        resolveSupport = {
          properties = {
            "documentation",
            "detail",
            "additionalTextEdits",
            "command",
            "data",
          },
        },
        insertTextModeSupport = { valueSet = { 1 } },
        labelDetailsSupport = true,
      },
      completionList = {
        itemDefaults = {
          "commitCharacters",
          "editRange",
          "insertTextFormat",
          "insertTextMode",
          "data",
        },
      },
      contextSupport = true,
      insertTextMode = 1,
    },
  },
}

local function apply_defaults()
  if defaults_applied then
    return
  end

  defaults_applied = true
  vim.lsp.config("*", { capabilities = default_capabilities })
end

local fallback_registered = {}
local enabled_servers = {} ---@type table<string, true>

--- Enable an LSP config globally via `vim.lsp.enable()`.
--- If the config declares `fallback_config`, a `<name>_fallback` variant is
--- registered on first call and enabled alongside the base config.
--- @param name string
function M.enable(name)
  apply_defaults()

  if not fallback_registered[name] then
    local cfg = vim.lsp.config[name]
    if cfg and cfg.fallback_config then
      fallback_registered[name] = true
      require("lib.fallback_config").register_fallback_lsp(name)
      if not enabled_servers[name .. "_fallback"] then
        enabled_servers[name .. "_fallback"] = true
        pcall(vim.lsp.enable, name .. "_fallback")
      end
    end
  end

  if not enabled_servers[name] then
    enabled_servers[name] = true
    vim.lsp.enable(name)
  end
end

--- Re-fire the `nvim.lsp.enable` FileType autocmd for a single buffer.
--- Used by tool-installer after a server binary becomes available.
---@param bufnr integer
function M.reattach(bufnr)
  pcall(vim.api.nvim_exec_autocmds, "FileType", {
    group = "nvim.lsp.enable",
    buffer = bufnr,
    modeline = false,
  })
end

function M.ensure_defaults()
  apply_defaults()
end

return M
