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
  -- vim.fs.find stop is exclusive — use parent so git root is searched
  local stop = root and vim.fn.fnamemodify(root, ":h") or vim.env.HOME
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

--- Register a `<name>_fallback` LSP variant for configs that declare
--- `fallback_config`. Overrides `root_dir` on both the base and fallback
--- configs so only the matching variant attaches per buffer.
--- @param name string LSP config name (e.g. "rumdl")
function M.register_fallback_lsp(name)
  local base = vim.lsp.config[name]
  local spec = base and base.fallback_config
  if not spec then
    return
  end

  local fallback_name = name .. "_fallback"
  local markers = base.root_markers or { ".git" }

  -- Build fallback cmd: base cmd + config flags
  local fallback_cmd = vim.deepcopy(base.cmd)
  local flag_list = type(spec.flag) == "table" and vim.deepcopy(spec.flag)
    or { spec.flag }
  vim.list_extend(fallback_cmd, flag_list)
  table.insert(fallback_cmd, spec.fallback)

  vim.lsp.config(fallback_name, {
    cmd = fallback_cmd,
    filetypes = base.filetypes,
    root_markers = markers,
  })

  -- Gate each variant via root_dir: only call on_dir when the buffer's
  -- config context matches (has project config → base, no config → fallback).
  local function make_root_dir(wants_project_config)
    return function(bufnr, on_dir)
      local path = vim.api.nvim_buf_get_name(bufnr)
      if path == "" then
        return
      end
      if M.has_project_config(spec, path) == wants_project_config then
        local root = vim.fs.root(bufnr, markers) or vim.fn.getcwd()
        on_dir(root)
      end
    end
  end

  vim.lsp.config(name, { root_dir = make_root_dir(true) })
  vim.lsp.config(fallback_name, { root_dir = make_root_dir(false) })
end

return M
