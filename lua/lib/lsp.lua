local M = {}

local defaults_applied = false
local retry_tokens = {} ---@type table<string, table>
local RETRY_DELAY_MS = 350
local RETRY_TIMEOUT_MS = 15000

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

---@param name string
---@param bufnr integer
---@return boolean
local function has_client(name, bufnr)
  return #vim.lsp.get_clients({ bufnr = bufnr, name = name }) > 0
end

---@param name string
---@param bufnr integer
---@return string
local function retry_key(name, bufnr)
  return name .. ":" .. bufnr
end

local fallback_registered = {}
local enabled_servers = {} ---@type table<string, true>

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
      if not enabled_servers[name .. "_fallback"] then
        enabled_servers[name .. "_fallback"] = true
        pcall(vim.lsp.enable, name .. "_fallback")
      end
    end
  end

  -- vim.lsp.enable registers a FileType autocmd then runs doautoall on ALL
  -- buffers. doautoall crashes on otter companion buffers with E518. Guard:
  -- 1. Only call once per server (autocmd + _enabled_configs persist).
  -- 2. pcall the first call: the autocmd is registered before doautoall runs
  --    in Neovim's code, so even if doautoall fails on otter buffers the
  --    autocmd still works for future FileType events. We attach the current
  --    buffer explicitly via attach_enabled_configs below.
  if not enabled_servers[name] then
    enabled_servers[name] = true
    pcall(vim.lsp.enable, name)
  end

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

--- Ensure an LSP client is eventually attached to `bufnr`.
--- Re-runs enable + FileType-group attach until a client appears or timeout.
---@param name string
---@param bufnr integer|nil
---@param opts? {delay_ms?: integer, timeout_ms?: integer}
function M.enable_until_ready(name, bufnr, opts)
  M.enable(name, bufnr)

  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  if has_client(name, bufnr) then
    retry_tokens[retry_key(name, bufnr)] = nil
    return
  end

  local delay_ms = (opts and opts.delay_ms) or RETRY_DELAY_MS
  local timeout_ms = (opts and opts.timeout_ms) or RETRY_TIMEOUT_MS
  local started = vim.uv.now()
  local key = retry_key(name, bufnr)
  local token = {}
  retry_tokens[key] = token

  local function step()
    if retry_tokens[key] ~= token then
      return
    end
    if not vim.api.nvim_buf_is_valid(bufnr) then
      retry_tokens[key] = nil
      return
    end
    if has_client(name, bufnr) then
      retry_tokens[key] = nil
      return
    end
    if vim.uv.now() - started >= timeout_ms then
      retry_tokens[key] = nil
      return
    end

    M.enable(name, bufnr)
    vim.defer_fn(step, delay_ms)
  end

  vim.defer_fn(step, delay_ms)
end

function M.ensure_defaults()
  apply_defaults()
end

return M
