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

local function attach_enabled_configs(bufnr)
  pcall(vim.api.nvim_exec_autocmds, "FileType", {
    group = "nvim.lsp.enable",
    buffer = bufnr,
    modeline = false,
  })
end

local fallback_registered = {}

--- Enable an LSP config and attach it to the current buffer when needed.
--- If the config declares `fallback_config`, a `<name>_fallback` variant is
--- registered on first call and enabled alongside the base config.
--- @param name string
--- @param bufnr integer|nil
function M.enable(name, bufnr)
  apply_defaults()

  if not fallback_registered[name] then
    local cfg = vim.lsp.config[name]
    if cfg and cfg.fallback_config then
      fallback_registered[name] = true
      require("lib.fallback_config").register_fallback_lsp(name)
      vim.lsp.enable(name .. "_fallback")
    end
  end

  vim.lsp.enable(name)

  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  if vim.v.vim_did_enter == 1 then
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        attach_enabled_configs(bufnr)
      end
    end)
    return
  end

  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        attach_enabled_configs(bufnr)
      end
    end,
  })
end

function M.ensure_defaults()
  apply_defaults()
end

return M
