local M = {}

local sourced = {} ---@type table<string, true>

--- Directories whose `.nvim.lua` (and `.nvimrc`/`.exrc`) are trusted without a
--- `:trust` prompt. `wt` copies the same `.nvim.lua` into each worktree, but the
--- trust database (`stdpath('state')/nvim/trust`) keys entries by absolute path,
--- so every fresh worktree path would otherwise re-prompt. Empty by default —
--- populate from machine-local config, e.g. in `lua/local/init.lua`:
---   table.insert(require("lib.exrc").trust_roots, vim.fn.expand("~/work"))
M.trust_roots = {} ---@type string[]

--- True if `path` is `root` or lives beneath it. Both are resolved through
--- `fs_realpath` first so symlinked roots (e.g. `/tmp` → `/private/tmp`) still
--- match; `path` is expected to already be realpath-resolved by the caller.
---@param path string
---@param root string
---@return boolean
local function is_under(path, root)
  root = vim.fs.normalize(vim.uv.fs_realpath(root) or root)
  path = vim.fs.normalize(path)
  return path == root or vim.startswith(path, root .. "/")
end

--- Pre-trust every project rc file from cwd upward that lives under a trusted
--- root, so the built-in exrc (which runs after `init.lua`) loads them without a
--- `:trust` prompt. Idempotent: re-hashes each startup, so edits stay trusted
--- and edits outside the roots still prompt. Mirrors the built-in exrc's upward
--- search in `$VIMRUNTIME/lua/vim/_core/exrc.lua`.
function M.autotrust()
  if not vim.o.exrc then
    return
  end
  local files = vim.fs.find({ ".nvim.lua", ".nvimrc", ".exrc" }, {
    upward = true,
    type = "file",
    limit = math.huge,
  })
  for _, file in ipairs(files) do
    local real = vim.uv.fs_realpath(file) or file
    for _, root in ipairs(M.trust_roots) do
      if is_under(real, root) then
        vim.secure.trust({ action = "allow", path = file })
        break
      end
    end
  end
end

--- Source the nearest `.nvim.lua` in a parent directory.
--- Call this at the top of a child `.nvim.lua` to inherit shared project config.
--- Guards against double-sourcing (safe if both root and child are loaded).
function M.source_parent()
  local cwd = vim.fn.getcwd()
  local dir = vim.fn.fnamemodify(cwd, ":h")
  while dir ~= cwd do -- stop at filesystem root (fnamemodify returns same path)
    local f = dir .. "/.nvim.lua"
    if not sourced[f] and vim.uv.fs_stat(f) then
      sourced[f] = true
      vim.cmd.source(f)
      return
    end
    cwd = dir
    dir = vim.fn.fnamemodify(dir, ":h")
  end
end

--- Mark the current file as sourced (called automatically by the built-in exrc).
--- Prevents double-sourcing when a child calls source_parent() and the parent
--- was already loaded by exrc.
function M.mark(path)
  sourced[vim.fn.fnamemodify(path, ":p")] = true
end

return M
