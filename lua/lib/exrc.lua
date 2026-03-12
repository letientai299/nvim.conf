local M = {}

local sourced = {} ---@type table<string, true>

--- Source the nearest `.nvim.lua` in a parent directory.
--- Call this at the top of a child `.nvim.lua` to inherit shared project config.
--- Guards against double-sourcing (safe if both root and child are loaded).
function M.source_parent()
  local cwd = vim.fn.getcwd()
  local dir = vim.fn.fnamemodify(cwd, ':h')
  while dir ~= cwd do -- stop at filesystem root (fnamemodify returns same path)
    local f = dir .. '/.nvim.lua'
    if not sourced[f] and vim.uv.fs_stat(f) then
      sourced[f] = true
      vim.cmd.source(f)
      return
    end
    cwd = dir
    dir = vim.fn.fnamemodify(dir, ':h')
  end
end

--- Mark the current file as sourced (called automatically by the built-in exrc).
--- Prevents double-sourcing when a child calls source_parent() and the parent
--- was already loaded by exrc.
function M.mark(path)
  sourced[vim.fn.fnamemodify(path, ':p')] = true
end

return M
