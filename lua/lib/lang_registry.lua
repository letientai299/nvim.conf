local M = {
  formatters = {},
  formatters_by_ft = {},
  linters_by_ft = {},
  parsers = {},
  treesitter_ready = false,
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
  names = listify(names)
  for _, ft in ipairs(listify(fts)) do
    local dst = M.formatters_by_ft[ft] or {}
    merge_lists(dst, names)
    M.formatters_by_ft[ft] = dst
  end

  local conform = package.loaded["conform"]
  if conform then
    conform.formatters_by_ft = vim.tbl_deep_extend(
      "force",
      conform.formatters_by_ft or {},
      M.formatters_by_ft
    )
  end
end

function M.add_linter(fts, names)
  names = listify(names)
  for _, ft in ipairs(listify(fts)) do
    local dst = M.linters_by_ft[ft] or {}
    merge_lists(dst, names)
    M.linters_by_ft[ft] = dst
  end

  local lint = package.loaded["lint"]
  if lint then
    lint.linters_by_ft =
      vim.tbl_deep_extend("force", lint.linters_by_ft or {}, M.linters_by_ft)
  end
end

function M.add_formatter(name, config)
  M.formatters[name] = config

  local conform = package.loaded["conform"]
  if conform then
    conform.formatters =
      vim.tbl_deep_extend("force", conform.formatters or {}, M.formatters)
  end
end

function M.ensure_parsers(parsers)
  local missing = {}
  for _, parser in ipairs(listify(parsers)) do
    if not M.parsers[parser] then
      M.parsers[parser] = true
      missing[#missing + 1] = parser
    end
  end

  if M.treesitter_ready and #missing > 0 then
    require("nvim-treesitter").install(missing, { summary = false })
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

function M.activate_treesitter()
  M.treesitter_ready = true

  local parsers = {}
  for parser in pairs(M.parsers) do
    parsers[#parsers + 1] = parser
  end
  if #parsers > 0 then
    require("nvim-treesitter").install(parsers, { summary = false })
  end
end

return M
