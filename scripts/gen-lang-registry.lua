--- Generate lua/lib/lang_registry_gen.lua from ftplugin/ and lua/langs/shared/.
--- Run: nvim -l scripts/gen-lang-registry.lua
---
--- Parses ftplugin files to build ft → module mapping, then reads each lang
--- module to extract formatters, formatter_fts, and detect custom formatter_defs.

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")

--- Read a file and return its contents.
local function read_file(path)
  local f = io.open(path)
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()
  return content
end

--- Extract quoted strings from a table literal in source text.
--- Returns a list of strings, or nil if the field is not found.
local function extract_string_list(source, field)
  local match = source:match(field .. "%s*=%s*(%b{})")
  if not match then
    return nil
  end
  local result = {}
  for s in match:gmatch('"([^"]+)"') do
    result[#result + 1] = s
  end
  return result
end

--- Scan ftplugin/ to extract {ft, module, fn} entries.
--- Each ftplugin file follows: require("langs.shared.X").Y(buf)
--- Skips tailwind (no formatters).
local function parse_ftplugins()
  local dir = root .. "/ftplugin"
  local entries = {}
  for name, type in vim.fs.dir(dir) do
    if type == "file" and name:match("%.lua$") then
      local ft = name:gsub("%.lua$", "")
      local content = read_file(dir .. "/" .. name)
      if content then
        for mod, fn in
          content:gmatch('require%("(langs%.shared%.[^"]+)"%)[%.:](%w+)')
        do
          if mod ~= "langs.shared.tailwind" then
            entries[#entries + 1] = { ft = ft, mod = mod, fn = fn }
          end
        end
      end
    end
  end
  table.sort(entries, function(a, b)
    return a.ft < b.ft
  end)
  return entries
end

--- Parse a lang module source to extract formatter info from its entry.setup call.
--- Returns { formatters = string[], formatter_fts = string[]|nil, has_defs = bool }
local function parse_lang_module(path, fn_name)
  local content = read_file(path)
  if not content then
    return nil
  end

  -- Find the function body for the target function.
  -- Scope it to the next top-level `end` (column 1) to avoid matching
  -- fields from a subsequent function in the same file.
  local fn_pattern = "function%s+M%." .. fn_name .. "%s*%("
  local fn_start = content:find(fn_pattern)
  if not fn_start then
    return nil
  end

  local fn_end = content:find("\nend", fn_start, true)
  local fn_body = content:sub(fn_start, fn_end and fn_end + 3 or -1)

  local formatters = extract_string_list(fn_body, "formatters") or {}

  -- Resolve formatter_fts: table literal → string literal → variable ref → filetypes
  local formatter_fts = extract_string_list(fn_body, "formatter_fts")
  if not formatter_fts then
    local ft_str = fn_body:match('formatter_fts%s*=%s*"([^"]+)"')
    if ft_str then
      formatter_fts = { ft_str }
    end
  end
  if not formatter_fts then
    local var = fn_body:match("formatter_fts%s*=%s*(%w+)")
    if var and var ~= "nil" then
      formatter_fts = extract_string_list(content, "local%s+" .. var)
    end
  end
  if not formatter_fts then
    formatter_fts = extract_string_list(fn_body, "filetypes")
  end

  return {
    formatters = formatters,
    formatter_fts = formatter_fts,
    has_defs = fn_body:match("formatter_defs%s*=") ~= nil,
  }
end

--- Convert module path (langs.shared.foo) to file path.
local function mod_to_path(mod)
  return root .. "/lua/" .. mod:gsub("%.", "/") .. ".lua"
end

--- Escape a ft string for use as a Lua table key.
local function key_str(ft)
  if ft:match("^[%a_][%w_]*$") then
    return ft
  end
  return '["' .. ft .. '"]'
end

local function main()
  local ftplugins = parse_ftplugins()

  -- Cache parsed results: multiple fts may call the same module+fn.
  local parsed_cache = {}
  local function get_parsed(entry)
    local k = entry.mod .. ":" .. entry.fn
    if not parsed_cache[k] then
      parsed_cache[k] = parse_lang_module(mod_to_path(entry.mod), entry.fn)
        or {}
    end
    return parsed_cache[k]
  end

  -- Build formatters_by_ft and ft_loaders.
  -- For each ftplugin entry, resolve which fts get which formatters.
  local formatters_by_ft = {} -- ft -> { formatter_names }
  local ft_loaders = {} -- ft -> { mod, fn } (only for has_defs)
  local seen_fts = {} -- track which fts already have formatters assigned

  for _, entry in ipairs(ftplugins) do
    local info = get_parsed(entry)
    if info.formatters and #info.formatters > 0 then
      local fts = info.formatter_fts or { entry.ft }
      for _, ft in ipairs(fts) do
        if not seen_fts[ft] then
          seen_fts[ft] = true
          formatters_by_ft[ft] = info.formatters
          if info.has_defs then
            ft_loaders[ft] = { mod = entry.mod, fn = entry.fn }
          end
        end
      end
    end
  end

  -- Sort keys for stable output
  local fmt_keys = vim.tbl_keys(formatters_by_ft)
  table.sort(fmt_keys)
  local loader_keys = vim.tbl_keys(ft_loaders)
  table.sort(loader_keys)

  -- Find max key width for alignment
  local max_key = 0
  for _, ft in ipairs(fmt_keys) do
    max_key = math.max(max_key, #key_str(ft))
  end

  -- Emit
  local lines = {
    "--- Auto-generated by scripts/gen-lang-registry.lua — do not edit.",
    "--- Provides static formatter mappings and lazy loaders for the injected",
    "--- formatter. Regenerate: mise run gen-lang-registry",
    "local M = {}",
    "",
    "-- stylua: ignore",
    "M.formatters_by_ft = {",
  }

  for _, ft in ipairs(fmt_keys) do
    local names = formatters_by_ft[ft]
    local quoted = {}
    for _, n in ipairs(names) do
      quoted[#quoted + 1] = '"' .. n .. '"'
    end
    local k = key_str(ft)
    local pad = string.rep(" ", max_key - #k)
    lines[#lines + 1] = "  "
      .. k
      .. pad
      .. " = { "
      .. table.concat(quoted, ", ")
      .. " },"
  end
  lines[#lines + 1] = "}"
  lines[#lines + 1] = ""

  if #loader_keys > 0 then
    local max_loader_key = 0
    for _, ft in ipairs(loader_keys) do
      max_loader_key = math.max(max_loader_key, #key_str(ft))
    end
    lines[#lines + 1] =
      "-- Lazy loaders for filetypes with custom formatter_defs."
    lines[#lines + 1] =
      "-- These must call setup(nil) to register the formatter definition."
    lines[#lines + 1] = "-- stylua: ignore"
    lines[#lines + 1] = "M.ft_loaders = {"
    for _, ft in ipairs(loader_keys) do
      local loader = ft_loaders[ft]
      local k = key_str(ft)
      local pad = string.rep(" ", max_loader_key - #k)
      lines[#lines + 1] = "  "
        .. k
        .. pad
        .. ' = function() require("'
        .. loader.mod
        .. '").'
        .. loader.fn
        .. "(nil) end,"
    end
    lines[#lines + 1] = "}"
  else
    lines[#lines + 1] = "M.ft_loaders = {}"
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "return M"
  lines[#lines + 1] = ""

  local out_path = root .. "/lua/lib/lang_registry_gen.lua"
  local out = io.open(out_path, "w")
  if not out then
    print("error: cannot open " .. out_path .. " for writing")
    os.exit(1)
  end
  out:write(table.concat(lines, "\n"))
  out:close()
  print("wrote " .. out_path)
end

main()
