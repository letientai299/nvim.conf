local M = {}

---@class ThemeEntry
---@field name string
---@field colorscheme string
---@field before? string
---@field after? string

---@alias Theme string|ThemeEntry

---@class ThemePluginSpec
---@field [1]? string
---@field name? string
---@field themes? Theme[]

local this_dir = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))
local cache_path = vim.fn.stdpath("state") .. "/theme-spec_gen.lua"
local refresh_scheduled = false

local function title_case(s)
  return s:gsub("[_-]", " "):gsub("(%a)([%w]*)", function(first, rest)
    return first:upper() .. rest
  end)
end

local function theme_files()
  local files = {}

  for name, ftype in vim.fs.dir(this_dir) do
    if ftype == "file" and name:match("%.lua$") then
      if name ~= "catalog.lua" and name ~= "init.lua" then
        files[#files + 1] = name
      end
    end
  end

  table.sort(files)

  return files
end

local function mtime(path)
  local stat = vim.uv.fs_stat(path)
  if not stat or not stat.mtime then
    return nil
  end

  return stat.mtime.sec * 1000000000 + stat.mtime.nsec
end

local function cache_stale(files)
  local cached = mtime(cache_path)
  if not cached then
    return true
  end

  for _, file in ipairs(files) do
    local path = this_dir .. "/" .. file
    local current = mtime(path)
    if current and current > cached then
      return true
    end
  end

  return false
end

local function read_spec_body(path)
  local f = io.open(path)
  if not f then
    return nil
  end

  local text = f:read("*a")
  f:close()

  local _, body_start = text:find("^return%s+")
  if not body_start then
    return nil
  end

  return text:sub(body_start + 1):gsub("%s*$", "")
end

local function indent(text)
  return table.concat(
    vim.tbl_map(function(line)
      return "  " .. line
    end, vim.split(text, "\n", { plain = true })),
    "\n"
  )
end

local function write_cache(files)
  local f = io.open(cache_path, "w")
  if not f then
    return false
  end

  local lines = { "-- Auto-generated theme spec cache.", "return {" }

  for _, file in ipairs(files) do
    local body = read_spec_body(this_dir .. "/" .. file)
    if not body then
      f:close()
      return false
    end

    lines[#lines + 1] = indent(body) .. ","
  end

  lines[#lines + 1] = "}"

  f:write(table.concat(lines, "\n"))
  f:write("\n")
  f:close()

  require("lib.bytecache").compile(cache_path)

  return true
end

local function load_cache(files)
  if cache_stale(files) then
    write_cache(files)
  end

  local ok, specs = pcall(require("lib.bytecache").load, cache_path)
  if ok and type(specs) == "table" then
    return specs
  end
end

local function load_fallback(files)
  local specs = {}

  for _, file in ipairs(files) do
    specs[#specs + 1] = dofile(this_dir .. "/" .. file)
  end

  return specs
end

local function schedule_refresh()
  if refresh_scheduled then
    return
  end

  refresh_scheduled = true
  vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    once = true,
    callback = function()
      local files = theme_files()
      if cache_stale(files) then
        write_cache(files)
      end
    end,
  })
end

function M.load_specs()
  -- Fast path: load existing cache without staleness check.
  -- Regeneration is deferred until VeryLazy so the first paint stays quiet.
  local bytecache = require("lib.bytecache")
  local ok, specs = pcall(bytecache.load, cache_path)
  if ok and type(specs) == "table" then
    schedule_refresh()
    return specs
  end

  -- Cold start: no cache exists yet.
  local files = theme_files()
  ---@type ThemePluginSpec[]
  return load_cache(files) or load_fallback(files)
end

function M.collect_themes()
  ---@type Theme[]
  local themes = { "default" }

  for _, spec in ipairs(M.load_specs()) do
    for _, theme in ipairs(spec.themes or {}) do
      if type(theme) == "string" then
        themes[#themes + 1] = { name = title_case(theme), colorscheme = theme }
      else
        themes[#themes + 1] = {
          name = theme.name or title_case(theme.colorscheme),
          colorscheme = theme.colorscheme,
          before = theme.before,
          after = theme.after,
        }
      end
    end
  end

  return themes
end

return M
