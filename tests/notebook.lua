vim.opt.rtp:prepend(vim.fn.getcwd())

local api = vim.api
local notebook = require("lib.notebook")
local buf = api.nvim_get_current_buf()
for _, case in ipairs({
  { { "# Markdown", "```python", "x = 1", "```" }, false },
  { { "---", "jupytext:", "  format_name: myst", "---" }, true },
  { { "```{code-cell} ipython3", "x = 1", "```" }, true },
  { { "~~~{code-cell} python", "x = 1", "~~~" }, true },
  { { "```{code-cell} ir", "x <- 1", "```" }, false },
}) do
  api.nvim_buf_set_lines(buf, 0, -1, false, case[1])
  assert(notebook.is_myst(buf) == case[2], "Notebook detection failed")
end

api.nvim_buf_set_lines(buf, 0, -1, false, {
  "```{code-cell} ipython3",
  "x = 1",
  "```",
})
vim.bo.filetype = "markdown"
for _, key in ipairs({ "[b", "]b", "Q" }) do
  vim.keymap.set("n", key, "<Cmd>echo 'existing'<CR>", { buffer = buf })
end
notebook.setup_editing(buf)
for _, key in ipairs({ "[b", "]b", "Q" }) do
  assert(
    vim.fn.maparg(key, "n") == "<Cmd>echo 'existing'<CR>",
    "Notebook changed an existing mapping"
  )
end
local plugin = { _ = {} }
package.loaded["lazy.core.config"] = {
  plugins = { ["otter.nvim"] = plugin },
}
local loads = 0
package.loaded.lazy = {
  load = function()
    loads = loads + 1
  end,
}
local callbacks = {}
package.loaded["tree-sitter-manager.installer"] = {
  install = function(_, callback)
    callbacks[#callbacks + 1] = callback
  end,
}
local activations = 0
local rafts = {}
package.loaded["otter.keeper"] = { rafts = rafts }
local ready = false
vim.treesitter.language.add = function()
  if not ready then
    error("Parser installation pending")
  end
end
vim.treesitter.get_parser = function()
  return {}
end
notebook.setup(buf)
assert(loads == 1 and activations == 0, "Activation ran during clone")
package.loaded.otter = {
  activate = function()
    activations = activations + 1
    assert(api.nvim_get_current_buf() == buf, "Wrong activation buffer")
    rafts[buf] = { buffers = { python = 123 } }
  end,
}
plugin._.loaded = true
api.nvim_exec_autocmds("User", {
  pattern = "LazyLoad",
  data = "otter.nvim",
})
vim.wait(50, function()
  return false
end, 10)
assert(#callbacks == 1 and activations == 0, "Parser readiness ignored")
ready = true
callbacks[1]()
assert(
  vim.wait(500, function()
    return activations == 1
  end),
  "Deferred activation missing"
)
callbacks[1]()
api.nvim_exec_autocmds("InsertLeave", { buffer = buf })
vim.wait(50, function()
  return false
end, 10)
assert(activations == 1, "Activation repeated")

local deleted = api.nvim_create_buf(false, false)
api.nvim_buf_set_lines(deleted, 0, -1, false, {
  "```{code-cell} python",
  "x = 2",
  "```",
})
notebook.setup(deleted)
api.nvim_buf_delete(deleted, { force = true })
callbacks[2]()
vim.wait(50, function()
  return false
end, 10)
assert(activations == 1, "Deleted buffer activated")
assert(not notebook.is_myst(deleted), "Deleted buffer detected")
print("Notebook detection and deferred activation checks passed")
