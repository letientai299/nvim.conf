local M = {}

local this_dir = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))
local cache_path = vim.fn.stdpath("state") .. "/plugin-spec_gen.lua"
local refresh_scheduled = false

local function files_signature(files)
  return table.concat(files, ",")
end

local function plugin_files()
  local files = {}

  for name, ftype in vim.fs.dir(this_dir) do
    if
      ftype == "file"
      and name:match("%.lua$")
      and name ~= "catalog.lua"
      and name ~= "init.lua"
    then
      files[#files + 1] = name
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

local function cached_files_signature()
  local f = io.open(cache_path)
  if not f then
    return nil
  end

  f:read("*l")
  local line = f:read("*l")
  f:close()
  if not line then
    return nil
  end

  return line:match("^%-%- source_files: (.*)$")
end

local function cache_stale(files)
  local cached = mtime(cache_path)
  if not cached then
    return true
  end

  if cached_files_signature() ~= files_signature(files) then
    return true
  end

  for _, file in ipairs(files) do
    local current = mtime(this_dir .. "/" .. file)
    if current and current > cached then
      return true
    end
  end

  return false
end

local function read_file(path)
  local f = io.open(path)
  if not f then
    return nil
  end

  local text = f:read("*a")
  f:close()

  return text
end

local function indent(text)
  return table.concat(
    vim.tbl_map(function(line)
      return "    " .. line
    end, vim.split(text, "\n", { plain = true })),
    "\n"
  )
end

local function write_cache(files)
  local f = io.open(cache_path, "w")
  if not f then
    return false
  end

  local lines = {
    "-- Auto-generated plugin spec cache.",
    "-- source_files: " .. files_signature(files),
    "return {",
  }

  for _, file in ipairs(files) do
    local text = read_file(this_dir .. "/" .. file)
    if not text then
      f:close()
      return false
    end

    lines[#lines + 1] = "  (function()"
    lines[#lines + 1] = indent(text)
    lines[#lines + 1] = "  end)(),"
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
      local files = plugin_files()
      if cache_stale(files) then
        write_cache(files)
      end
    end,
  })
end

function M.load_specs()
  local files = plugin_files()
  local bytecache = require("lib.bytecache")
  if not cache_stale(files) then
    local ok, specs = pcall(bytecache.load, cache_path)
    if ok and type(specs) == "table" then
      schedule_refresh()
      return specs
    end
  end

  return load_cache(files) or load_fallback(files)
end

return M
