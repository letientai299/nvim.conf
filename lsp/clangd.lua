-- Flag policy for clangd lives here so every C/C++/CUDA project gets identical
-- behavior. A project can shadow only the *binary* by shipping an executable at
-- `<root>/.nvim/clangd` -- e.g. a wrapper that runs clangd inside a container
-- where the real toolchain (CUDA headers, matching libc) lives, so diagnostics
-- match the actual build instead of the host's missing headers. The wrapper
-- inherits these args via `"$@"`; it owns only transport, not flag policy.
--
-- Root pinning: the wrapper is resolved from `config.root_dir`, so the project
-- must place a root marker (e.g. `.clangd`) beside `.nvim/` when a `.git` lives
-- in a parent dir, otherwise the LSP root climbs past the wrapper.
-- No --header-insertion here: iwyu is already clangd's default, and passing it
-- explicitly lets the flag provider (combined last) override a project
-- `.clangd` Completion.HeaderInsertion. CUDA projects need that override --
-- IWYU offers clang's __clang_cuda_builtin_vars.h for blockIdx, which nvcc
-- does not ship. https://clangd.llvm.org/config#headerinsertion
local clangd_args = {
  "--background-index",
  "--clang-tidy",
  "--completion-style=detailed",
}

--- Prefer a project-local `.nvim/clangd` wrapper (transport shim for a remote
--- toolchain) over the system `clangd` on PATH.
---@param root string|nil
---@return string
local function resolve_clangd(root)
  if root then
    local wrapper = root .. "/.nvim/clangd"
    if vim.fn.executable(wrapper) == 1 then
      return wrapper
    end
  end
  return "clangd"
end

return {
  cmd = function(dispatchers, config)
    local root = config.root_dir
    local cmd = { resolve_clangd(root) }
    vim.list_extend(cmd, clangd_args)
    return vim.lsp.rpc.start(cmd, dispatchers, {
      cwd = config.cmd_cwd or root,
      env = config.cmd_env,
      detached = config.detached,
    })
  end,
  filetypes = { "c", "cpp", "cuda", "objc", "objcpp" },
  root_markers = {
    ".clangd",
    "compile_commands.json",
    "compile_flags.txt",
    ".clang-format",
    ".git",
  },
}
