---@class tool-installer.Tool
---@field bin string
---@field name? string
---@field version? string        -- mise only (tool@version syntax)
---@field mise? string
---@field brew? string
---@field script? string
---@field dependencies? string[]

---@class tool-installer.Config
---@field catalog table<string, tool-installer.Tool>
---@field script_dir string
---@field cache_ttl integer

local M = {}

---@type tool-installer.Config
local _config = {
  catalog = {},
  script_dir = "",
  cache_ttl = 3600,
}

--- Bins currently being installed. Maps bin → list of subscriber callbacks
--- that fire when the install settles. Subscribers are added by concurrent
--- ensure() calls that encounter an in-flight install for the same bin.
---@type table<string, fun(ok: boolean)[]>
local _installing = {}

---@param opts tool-installer.Config
function M.setup(opts)
  _config = vim.tbl_deep_extend("force", _config, opts or {})
  if _config.script_dir ~= "" then
    require("tool-installer.backend.script").set_script_dir(_config.script_dir)
  end
end

--- Read-only copy of current config. For health checks.
---@return tool-installer.Config
function M.get_config()
  return vim.deepcopy(_config)
end

local BACKENDS = {
  { field = "mise", mod = "tool-installer.backend.mise" },
  { field = "brew", mod = "tool-installer.backend.brew" },
  { field = "script", mod = "tool-installer.backend.script" },
}

--- Pick the first available backend for a tool spec.
---@param tool tool-installer.Tool
---@return {backend: table, spec: string}?
local function select_backend(tool)
  for _, b in ipairs(BACKENDS) do
    local spec = tool[b.field]
    if spec then
      local backend = require(b.mod)
      if backend.available() then
        return { backend = backend, spec = spec }
      end
    end
  end
  return nil
end

--- Force Neovim to re-scan PATH so vim.fn.executable picks up new shims.
local function rehash()
  vim.env.PATH = vim.env.PATH
end

--- Notify all subscribers waiting on a bin, then clear the entry.
---@param bin string
---@param ok boolean
local function settle_bin(bin, ok)
  local subs = _installing[bin]
  _installing[bin] = nil
  if subs then
    for _, cb in ipairs(subs) do
      cb(ok)
    end
  end
end

--- Install a list of tools (already resolved and ordered).
--- Groups tools by shared mise spec to deduplicate installs.
---@param tools tool-installer.Tool[]
---@param on_done fun()
local function install_batch(tools, on_done)
  if #tools == 0 then
    on_done()
    return
  end

  local cache = require("tool-installer.cache")
  local progress = require("tool-installer.progress")
  local remaining = 0
  local mise_groups = {} ---@type table<string, tool-installer.Tool[]>
  local jobs = {} ---@type {tool: tool-installer.Tool, backend: table, spec: string}[]

  local function check_done()
    remaining = remaining - 1
    if remaining == 0 then
      cache.flush()
      local ok, err = pcall(on_done)
      if not ok then
        vim.notify(
          "[tool-installer] on_complete error: " .. tostring(err),
          vim.log.levels.ERROR
        )
      end
    end
  end

  for _, t in ipairs(tools) do
    if _installing[t.bin] then
      -- Tool is being installed by another concurrent batch — subscribe
      remaining = remaining + 1
      _installing[t.bin][#_installing[t.bin] + 1] = function()
        check_done()
      end
    elseif t.mise and mise_groups[t.mise] then
      -- Deduplicate shared mise specs — piggyback on existing job
      mise_groups[t.mise][#mise_groups[t.mise] + 1] = t
      _installing[t.bin] = {}
    else
      local choice = select_backend(t)
      if choice then
        if t.mise then
          mise_groups[t.mise] = { t }
        end
        _installing[t.bin] = {}
        remaining = remaining + 1
        jobs[#jobs + 1] =
          { tool = t, backend = choice.backend, spec = choice.spec }
      else
        vim.notify(
          "[tool-installer] No backend for " .. (t.name or t.bin),
          vim.log.levels.WARN
        )
      end
    end
  end

  if remaining == 0 then
    on_done()
    return
  end

  local tracker = progress.start(remaining)

  for _, job in ipairs(jobs) do
    local t = job.tool
    local display = t.name or t.bin
    tracker:installing(display)

    job.backend.install(job.spec, t.version, function(ok, err)
      vim.schedule(function()
        rehash()
        local group = t.mise and mise_groups[t.mise] or { t }
        if ok then
          for _, gt in ipairs(group) do
            if vim.fn.executable(gt.bin) == 1 then
              cache.set(gt.bin, true)
            end
          end
          tracker:installed(display)
        else
          tracker:fail(display, err)
        end

        for _, gt in ipairs(group) do
          settle_bin(gt.bin, ok)
        end
        check_done()
      end)
    end)
  end
end

--- Ensure all listed tools are available; install missing ones.
---@param tools tool-installer.Tool[]
---@param on_complete? fun()
function M.ensure(tools, on_complete)
  local cache = require("tool-installer.cache")
  local resolve = require("tool-installer.resolve")
  local catalog = _config.catalog
  on_complete = on_complete or function() end

  -- Flatten dependencies from catalog
  local ordered = resolve.flatten(tools, catalog)

  -- Partition into installed / missing
  local missing = {}
  for _, t in ipairs(ordered) do
    if not cache.is_available(t.bin, _config.cache_ttl) then
      missing[#missing + 1] = t
    end
  end
  cache.flush()

  if #missing == 0 then
    on_complete()
    return
  end

  -- Two-wave install: direct dependencies first (wave 1), then everything
  -- else (wave 2). Only supports one level of depth — sufficient for the
  -- current catalog (runtimes → tools). Deeper chains would need N waves
  -- derived from the topological order.
  local dep_bins = {} ---@type table<string, true>
  for _, t in ipairs(missing) do
    if t.dependencies then
      for _, dep_name in ipairs(t.dependencies) do
        local dep = catalog[dep_name]
        if dep then
          dep_bins[dep.bin] = true
        end
      end
    end
  end

  local wave1 = {}
  local wave2 = {}
  for _, t in ipairs(missing) do
    if dep_bins[t.bin] then
      wave1[#wave1 + 1] = t
    else
      wave2[#wave2 + 1] = t
    end
  end

  if #wave1 == 0 then
    install_batch(wave2, on_complete)
    return
  end

  install_batch(wave1, function()
    -- Skip wave2 dependents whose dependencies failed to install
    local failed_bins = {}
    for _, t in ipairs(wave1) do
      if vim.fn.executable(t.bin) ~= 1 then
        failed_bins[t.bin] = true
      end
    end

    if vim.tbl_isempty(failed_bins) then
      install_batch(wave2, on_complete)
      return
    end

    local viable = {}
    for _, t in ipairs(wave2) do
      local blocked = false
      if t.dependencies then
        for _, dep_name in ipairs(t.dependencies) do
          local dep = catalog[dep_name]
          if dep and failed_bins[dep.bin] then
            blocked = true
            break
          end
        end
      end
      if not blocked then
        viable[#viable + 1] = t
      end
    end

    install_batch(viable, on_complete)
  end)
end

return M
