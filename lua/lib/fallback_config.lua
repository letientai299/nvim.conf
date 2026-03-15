local M = {}

--- @class FallbackSpec
--- @field names string[] config file names to search for (e.g. { ".rumdl.toml", "rumdl.toml" })
--- @field flag string|string[] CLI flag(s) to prepend before the fallback path
--- @field fallback string absolute path to the fallback config file
--- @field extra_dirs? string[] dirs relative to git root to check (e.g. { ".config" })

--- Check if a project-level config exists near `path`.
--- Searches upward from `path` to the git root (or $HOME), then optionally
--- checks `extra_dirs` relative to the git root.
--- @param spec FallbackSpec
--- @param path string file or directory path
--- @return boolean
function M.has_project_config(spec, path)
  local root = vim.fs.root(path, ".git")
  local stop = root or vim.env.HOME
  if
    #vim.fs.find(spec.names, {
      path = path,
      upward = true,
      stop = stop,
      type = "file",
      limit = 1,
    }) > 0
  then
    return true
  end
  if root and spec.extra_dirs then
    for _, dir in ipairs(spec.extra_dirs) do
      for _, name in ipairs(spec.names) do
        if vim.uv.fs_stat(root .. "/" .. dir .. "/" .. name) then
          return true
        end
      end
    end
  end
  return false
end

--- Build CLI flags that inject the fallback config when no project config exists.
--- Returns `{}` when a project config is found, or `{ flag, fallback }` otherwise.
--- @param spec FallbackSpec
--- @param path string file or directory path
--- @return string[]
function M.flags(spec, path)
  if M.has_project_config(spec, path) then
    return {}
  end
  local flags = type(spec.flag) == "table" and vim.deepcopy(spec.flag)
    or { spec.flag }
  table.insert(flags, spec.fallback)
  return flags
end

return M
