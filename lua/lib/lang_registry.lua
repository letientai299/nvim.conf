local M = {
  formatters = {},
  formatters_by_ft = {},
  linters_by_ft = {},
}

local function listify(value)
  if type(value) == "table" then
    return value
  end
  return { value }
end

local function merge_lists(dst, src)
  local seen = {}
  for _, item in ipairs(dst) do
    seen[item] = true
  end
  for _, item in ipairs(src) do
    if not seen[item] then
      dst[#dst + 1] = item
      seen[item] = true
    end
  end
end

function M.add_formatters(fts, names)
  fts = listify(fts)
  names = listify(names)
  for _, ft in ipairs(fts) do
    local dst = M.formatters_by_ft[ft] or {}
    merge_lists(dst, names)
    M.formatters_by_ft[ft] = dst
  end

  local conform = package.loaded["conform"]
  if conform and conform.formatters_by_ft then
    for _, ft in ipairs(fts) do
      rawset(conform.formatters_by_ft, ft, M.formatters_by_ft[ft])
    end
  end
end

function M.add_linter(fts, names)
  fts = listify(fts)
  names = listify(names)
  for _, ft in ipairs(fts) do
    local dst = M.linters_by_ft[ft] or {}
    merge_lists(dst, names)
    M.linters_by_ft[ft] = dst
  end

  local lint = package.loaded["lint"]
  if lint and lint.linters_by_ft then
    for _, ft in ipairs(fts) do
      rawset(lint.linters_by_ft, ft, M.linters_by_ft[ft])
    end
  end
end

function M.add_formatter(name, config)
  M.formatters[name] = config

  local conform = package.loaded["conform"]
  if conform and conform.formatters then
    conform.formatters[name] = config
  end
end

function M.activate_conform(opts)
  opts.formatters =
    vim.tbl_deep_extend("force", opts.formatters or {}, M.formatters)
  opts.formatters_by_ft = vim.tbl_deep_extend(
    "force",
    opts.formatters_by_ft or {},
    M.formatters_by_ft
  )
end

function M.activate_lint(opts)
  opts.linters_by_ft =
    vim.tbl_deep_extend("force", opts.linters_by_ft or {}, M.linters_by_ft)
end

--- Install lazy formatter lookup on conform.formatters_by_ft.
--- Pre-populates static mappings from the generated registry and installs an
--- __index metatable for filetypes that need custom formatter_defs loaded on
--- demand (e.g., rumdl_fix in docs.lua).
function M.install_lazy_formatters()
  local ok, gen = pcall(require, "lib.lang_registry_gen")
  if not ok then
    return
  end

  local fbt = require("conform").formatters_by_ft

  -- Merge static formatters_by_ft. Skip fts with ft_loaders so __index fires
  -- and registers their custom formatter_defs on first access.
  for ft, names in pairs(gen.formatters_by_ft) do
    if rawget(fbt, ft) == nil and not gen.ft_loaders[ft] then
      rawset(fbt, ft, names)
    end
  end

  -- Install __index for fts with custom formatter_defs.
  if not next(gen.ft_loaders) or getmetatable(fbt) then
    return
  end
  setmetatable(fbt, {
    __index = function(t, ft)
      local loader = gen.ft_loaders[ft]
      if not loader then
        return nil
      end
      -- Clear first: loader() may touch formatters_by_ft again while it runs.
      gen.ft_loaders[ft] = nil
      loader()
      return rawget(t, ft)
    end,
  })
end

return M
