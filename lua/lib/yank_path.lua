-- Shared file-path yank helpers used by oil keymaps and normal-buffer keymaps.

local M = {}

--- Compute a relative path from `base` to `target`, including `../` segments.
function M.relpath(target, base)
  local t =
    vim.split(vim.fn.fnamemodify(target, ":p"), "/", { trimempty = true })
  local b = vim.split(vim.fn.fnamemodify(base, ":p"), "/", { trimempty = true })
  local common = 0
  for i = 1, math.min(#t, #b) do
    if t[i] ~= b[i] then
      break
    end
    common = i
  end
  local parts = {}
  for _ = common + 1, #b do
    parts[#parts + 1] = ".."
  end
  for i = common + 1, #t do
    parts[#parts + 1] = t[i]
  end
  return table.concat(parts, "/")
end

--- Return the git repo root for cwd, or nil outside a repo.
function M.git_root()
  return vim.fs.root(0, ".git")
end

--- Yank `text` to the system clipboard and echo it.
function M.yank(text)
  vim.fn.setreg("+", text)
  vim.notify(text, vim.log.levels.INFO)
end

--- Yank just the filename of `path`.
function M.yank_name(path)
  if not path then
    return
  end
  M.yank(vim.fn.fnamemodify(path, ":t"))
end

--- Yank `path` relative to cwd.
function M.yank_relative(path)
  if not path then
    return
  end
  M.yank(M.relpath(path, vim.fn.getcwd()))
end

--- Yank the absolute `path`.
function M.yank_absolute(path)
  if not path then
    return
  end
  M.yank(path)
end

--- Yank `path` relative to git root (falls back to cwd-relative).
function M.yank_git(path)
  if not path then
    return
  end
  local root = M.git_root()
  if root then
    root = root:gsub("/?$", "/")
    M.yank(path:sub(#root + 1))
  else
    M.yank(vim.fn.fnamemodify(path, ":."))
  end
end

return M
