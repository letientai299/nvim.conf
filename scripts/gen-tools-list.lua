--- Generate a flat list of mise tool specs from Lua source.
--- Run: nvim -l scripts/gen-tools-list.lua
---
--- Scans lua/langs/shared/*.lua and lua/lib/{prettier,biome}.lua for
--- `mise = "..."` fields, infers required runtimes from prefixes, adds
--- extras (CLI tools not tied to any lang module), and prints one spec
--- per line to stdout (sorted, deduplicated).

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

--- Extract all `mise = "..."` values from source text.
local function extract_mise_specs(source)
  local specs = {}
  for spec in source:gmatch('mise%s*=%s*"([^"]+)"') do
    specs[#specs + 1] = spec
  end
  return specs
end

--- Infer the runtime needed for a mise spec prefix.
local runtime_map = {
  ["go:"] = "go",
  ["npm:"] = "node",
  ["cargo:"] = "rust",
  ["dotnet:"] = "dotnet",
}

--- Tools not declared in any lang module but needed for a complete setup.
local extras = {
  "rust",
  "fzf",
  "fd",
  "ripgrep",
  "tree-sitter",
}

local function main()
  local seen = {}
  local specs = {}

  local function add(spec)
    if seen[spec] then
      return
    end
    seen[spec] = true
    specs[#specs + 1] = spec
    -- Auto-add the runtime implied by the spec prefix
    for prefix, runtime in pairs(runtime_map) do
      if spec:sub(1, #prefix) == prefix then
        add(runtime)
      end
    end
  end

  -- Scan lua/langs/shared/*.lua
  local lang_dir = root .. "/lua/langs/shared"
  for name, type in vim.fs.dir(lang_dir) do
    if type == "file" and name:match("%.lua$") then
      local content = read_file(lang_dir .. "/" .. name)
      if content then
        for _, spec in ipairs(extract_mise_specs(content)) do
          add(spec)
        end
      end
    end
  end

  -- Scan lib files with tool declarations
  for _, path in ipairs({
    root .. "/lua/lib/prettier.lua",
    root .. "/lua/lib/biome.lua",
  }) do
    local content = read_file(path)
    if content then
      for _, spec in ipairs(extract_mise_specs(content)) do
        add(spec)
      end
    end
  end

  -- Add extras
  for _, spec in ipairs(extras) do
    add(spec)
  end

  table.sort(specs)
  io.write(table.concat(specs, " ") .. "\n")
end

main()
