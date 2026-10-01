vim.opt.rtp:prepend(vim.fn.getcwd())

local registered, enabled, ensured
package.loaded["lib.lang_registry"] = {
  add_formatters = function()
    registered = registered + 1
  end,
  add_tools = function() end,
}
package.loaded["lib.lsp"] = {
  enable = function()
    enabled = enabled + 1
  end,
}
package.loaded["tool-installer"] = {
  ensure = function()
    ensured = ensured + 1
  end,
}

local entry = require("langs.shared.entry")
for _, case in ipairs({
  { name = "startup", deferred = true },
  { name = "ready" },
  { name = "deleted", deferred = true, deleted = true },
  { name = "registry", deferred = true, registry = true },
}) do
  registered, enabled, ensured = 0, 0, 0
  vim.g.did_very_lazy = not case.deferred
  local buf = vim.api.nvim_create_buf(true, false)
  vim.bo[buf].filetype = "markdown"
  entry.setup(case.name, not case.registry and buf or nil, {
    lsp = "marksman",
    formatters = { "prettier" },
    tools = { { bin = "marksman" } },
  })
  if case.registry then
    assert(registered == 1 and enabled == 0, case.name)
  elseif case.deferred then
    assert(registered == 0 and enabled == 0 and ensured == 0, case.name)
  else
    assert(registered == 1 and enabled == 1 and ensured == 1, case.name)
  end
  if case.deleted then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
  vim.g.did_very_lazy = true
  vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
  assert(registered == 1, case.name .. ": registry")
  local skips_attach = case.deleted or case.registry
  assert(enabled == (skips_attach and 0 or 1), case.name .. ": LSP")
  assert(ensured == enabled, case.name .. ": tools")
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end
print("Language startup checks passed")
