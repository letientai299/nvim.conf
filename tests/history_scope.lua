vim.opt.rtp:prepend(vim.fn.getcwd())
local plugin = { _ = { loaded = false } }
package.loaded["lazy.core.config"] = { plugins = { ["fzf-lua"] = plugin } }
local spec = dofile("lua/plugins/fzf-lua.lua")
local open_history
for _, key in ipairs(spec.keys) do
  if key[1] == "<leader>fh" then
    open_history = key[2]
    break
  end
end
assert(type(open_history) == "function", "History keymap missing")
open_history()
assert(
  not package.loaded["fzf-lua"],
  "History loaded before dependency readiness"
)

local calls = 0
local history
package.loaded["fzf-lua"] = {
  oldfiles = function(opts)
    calls = calls + 1
    history = opts
  end,
}
vim.api.nvim_exec_autocmds("User", { pattern = "LazyLoad", data = "other" })
assert(calls == 0, "History opened for another plugin")
plugin._.loaded = true
vim.api.nvim_exec_autocmds("User", { pattern = "LazyLoad", data = "fzf-lua" })
assert(calls == 1, "Deferred history did not open")
vim.api.nvim_exec_autocmds("User", { pattern = "LazyLoad", data = "fzf-lua" })
assert(calls == 1, "Deferred history opened twice")
open_history()
assert(calls == 2, "Loaded history did not open immediately")
local cwd = vim.fn.getcwd()
assert(history.cwd == vim.fs.root(cwd, ".git"), "Git root scope missing")
assert(
  history.cwd_only and history.prompt == "History (Git root)> ",
  "Git root default missing"
)
history.actions["ctrl-g"].fn(nil, { last_query = "needle" })
assert(history.cwd == cwd and history.query == "needle", "CWD query missing")
history.actions["ctrl-g"].fn(nil, {})
assert(
  not history.cwd_only and history.prompt == "History (All)> ",
  "All scope missing"
)
local root = vim.fs.root
vim.fs.root = function() end
open_history()
assert(history.cwd == cwd and history.cwd_only, "CWD fallback missing")
assert(history.prompt == "History (CWD)> ", "CWD prompt missing")
vim.fs.root = root
print("Deferred history passed")
