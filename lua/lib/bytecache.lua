local M = {}

--- Load a Lua file, preferring pre-compiled .luac bytecode.
--- Falls back to source .lua on missing or stale .luac.
---@param path string path to the .lua file
---@return any result of executing the file
function M.load(path)
  local luac = path .. "c"
  local chunk, err = loadfile(luac)
  if chunk then
    return chunk()
  end
  -- Stale/corrupt .luac — remove so it doesn't block future loads
  if err then
    os.remove(luac)
  end
  local result = dofile(path)
  -- Lazily compile .luac for next startup
  M.compile(path)
  return result
end

--- Write Lua source to `path` and compile a .luac sibling.
---@param path string path to the .lua file (must already exist or be writable)
function M.compile(path)
  local chunk = loadfile(path)
  if not chunk then
    return
  end
  local luac = path .. "c"
  local f = io.open(luac, "wb")
  if not f then
    return
  end
  f:write(string.dump(chunk))
  f:close()
end

return M
