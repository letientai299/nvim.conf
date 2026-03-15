local M = {}

---@alias lib.tools.Kind "lsp"|"fmt"|"lint"|"check"
---
---@class lib.tools.Tool
---@field name? string        -- display name for notifications; defaults to `bin`
---@field bin string          -- executable name to look up on PATH
---@field kind lib.tools.Kind
---@field mise? string        -- global mise spec, e.g. "go:golang.org/x/tools/gopls"
---@field script? string      -- scripts/<name> fallback for tools mise cannot install directly

local CACHE_TTL = 3600 -- 1 hour
local cache_path = vim.fn.stdpath("cache") .. "/tool-check.json"
local _cache ---@type table<string, boolean>?
local _cache_dirty = false

local function load_cache()
  if _cache then
    return _cache
  end
  local f = io.open(cache_path)
  if f then
    local ok, data = pcall(vim.json.decode, f:read("*a"))
    f:close()
    if ok and data and data.ts and (os.time() - data.ts) < CACHE_TTL then
      _cache = data.bins or {}
      return _cache
    end
  end
  _cache = {}
  return _cache
end

local function save_cache()
  if not _cache_dirty then
    return
  end
  local f = io.open(cache_path, "w")
  if f then
    f:write(vim.json.encode({ ts = os.time(), bins = _cache }))
    f:close()
    _cache_dirty = false
  end
end

local function is_executable(bin)
  local cache = load_cache()
  -- Cached false short-circuits within the current session. Cached true and
  -- uncached entries are re-verified so external uninstalls are noticed.
  if cache[bin] == false then
    return false
  end
  local result = vim.fn.executable(bin) == 1
  if cache[bin] ~= result then
    cache[bin] = result
    _cache_dirty = true
  end
  return result
end

--- Mise backends like go:, npm:, cargo:, and dotnet: need their runtime
--- pre-installed. Returns the runtime name (e.g. "go", "node") or nil.
---@param mise_spec string
---@return string?
local function runtime_for(mise_spec)
  local runtimes = {
    ["go:"] = "go",
    ["npm:"] = "node",
    ["cargo:"] = "rust",
    ["dotnet:"] = "dotnet",
  }
  for prefix, runtime in pairs(runtimes) do
    if vim.startswith(mise_spec, prefix) then
      return runtime
    end
  end
  return nil
end

--- Install prerequisite runtimes for mise backend specs, then call `proceed`.
--- Passes a set of failed runtime names so callers can skip dependent tools.
---@param missing lib.tools.Tool[]
---@param proceed fun(failed_runtimes: table<string, true>)
local function ensure_runtimes(missing, proceed)
  local needed = {}
  for _, t in ipairs(missing) do
    if t.mise then
      local rt = runtime_for(t.mise)
      if rt and not needed[rt] and vim.fn.executable(rt) ~= 1 then
        needed[rt] = true
      end
    end
  end

  local runtimes = {}
  for rt in pairs(needed) do
    runtimes[#runtimes + 1] = rt
  end

  if #runtimes == 0 then
    proceed({})
    return
  end

  local failed = {}
  local remaining = #runtimes
  for _, rt in ipairs(runtimes) do
    vim.notify("Installing " .. rt .. " runtime...", vim.log.levels.INFO)
    vim.system({ "mise", "use", "-g", rt }, {}, function(result)
      vim.schedule(function()
        if result.code == 0 then
          load_cache()[rt] = true
          _cache_dirty = true
          vim.notify(rt .. " runtime ready.", vim.log.levels.INFO)
        else
          failed[rt] = true
          vim.notify(
            "Failed to install " .. rt .. " runtime: " .. (result.stderr or ""),
            vim.log.levels.ERROR
          )
        end
        remaining = remaining - 1
        if remaining == 0 then
          save_cache()
          proceed(failed)
        end
      end)
    end)
  end
end

--- Ensure tools are installed. Missing tools with a `mise` or `script` field
--- are auto-installed asynchronously. Prerequisite runtimes (go, node, rust,
--- dotnet) are installed first when needed. `on_complete` runs once every
--- install branch has settled, or immediately when nothing is missing.
---@param tools lib.tools.Tool[]
---@param on_complete? fun()
function M.ensure(tools, on_complete)
  local missing = {}
  for _, t in ipairs(tools) do
    if not is_executable(t.bin) then
      missing[#missing + 1] = t
    end
  end
  save_cache()

  if #missing == 0 then
    if on_complete then
      on_complete()
    end
    return
  end

  ensure_runtimes(missing, function(failed_runtimes)
    local remaining = #missing -- async barrier; every branch below decrements once
    local config_dir = vim.fn.stdpath("config") --[[@as string]]
    -- Group tools by mise spec to deduplicate installs
    -- (e.g. npm:vscode-langservers-extracted provides multiple binaries)
    local mise_groups = {} ---@type table<string, lib.tools.Tool[]>

    for _, t in ipairs(missing) do
      -- Skip tools whose runtime failed to install
      if t.mise and failed_runtimes[runtime_for(t.mise)] then
        remaining = remaining - 1
        if remaining == 0 and on_complete then
          on_complete()
        end
        goto continue
      end

      local cmd
      if t.mise then
        if mise_groups[t.mise] then
          -- Already queued — just add to the group for post-install cache update
          mise_groups[t.mise][#mise_groups[t.mise] + 1] = t
          remaining = remaining - 1
          if remaining == 0 and on_complete then
            on_complete()
          end
          goto continue
        end
        mise_groups[t.mise] = { t }
        cmd = { "mise", "use", "-g", t.mise }
      elseif t.script then
        cmd = { config_dir .. "/scripts/" .. t.script }
      else
        remaining = remaining - 1
        vim.notify(
          "No installer for " .. (t.name or t.bin),
          vim.log.levels.WARN
        )
        if remaining == 0 and on_complete then
          on_complete()
        end
        goto continue
      end

      vim.notify(
        "Installing " .. (t.name or t.bin) .. "...",
        vim.log.levels.INFO
      )
      vim.system(cmd, {}, function(result)
        vim.schedule(function()
          -- Cache all binaries provided by this install (handles shared mise specs)
          local group = t.mise and mise_groups[t.mise] or { t }
          if result.code == 0 then
            local cache = load_cache()
            for _, gt in ipairs(group) do
              if vim.fn.executable(gt.bin) == 1 then
                cache[gt.bin] = true
                _cache_dirty = true
              end
            end
            vim.notify((t.name or t.bin) .. " ready.", vim.log.levels.INFO)
          else
            vim.notify(
              "Failed to install "
                .. (t.name or t.bin)
                .. ": "
                .. (result.stderr or ""),
              vim.log.levels.ERROR
            )
          end
          remaining = remaining - 1
          if remaining == 0 then
            save_cache()
            if on_complete then
              on_complete()
            end
          end
        end)
      end)
      ::continue::
    end
  end)
end

return M
