-- Yank helpers for file paths and text, used by oil and normal-buffer keymaps.

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

--- Yank `text` to the system clipboard and notify.
function M.put(text)
  vim.fn.setreg("+", text)
  vim.notify(text, vim.log.levels.INFO)
end

--- Yank just the filename of `path`.
function M.name(path)
  if not path then
    return
  end
  M.put(vim.fn.fnamemodify(path, ":t"))
end

--- Yank `path` relative to cwd.
function M.relative(path)
  if not path then
    return
  end
  M.put(M.relpath(path, vim.fn.getcwd()))
end

--- Yank the absolute `path`.
function M.absolute(path)
  if not path then
    return
  end
  M.put(path)
end

--- Yank `path` relative to git root (falls back to cwd-relative).
function M.git(path)
  if not path then
    return
  end
  local root = vim.fs.root(0, ".git")
  if root then
    root = root:gsub("/?$", "/")
    M.put(path:sub(#root + 1))
  else
    M.put(vim.fn.fnamemodify(path, ":."))
  end
end

return M
