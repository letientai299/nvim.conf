vim.opt.rtp:prepend(vim.fn.getcwd())

local loaded = {}
local plugins = {
  ["blink.cmp"] = {
    _ = { installed = true },
    dependencies = { "LuaSnip" },
  },
  LuaSnip = {
    _ = { installed = true },
    dependencies = { "friendly-snippets" },
  },
  ["friendly-snippets"] = { _ = { installed = false } },
  ["nvim-autopairs"] = { _ = { installed = false } },
  ["minuet-ai.nvim"] = { _ = { installed = true } },
}
package.loaded["lazy.core.config"] = { plugins = plugins }
package.loaded.lazy = {
  load = function(opts)
    vim.list_extend(loaded, opts.plugins)
    for _, name in ipairs(opts.plugins) do
      plugins[name]._.loaded = {}
    end
  end,
}

local original_mode = vim.api.nvim_get_mode
local mode = "i"
vim.api.nvim_get_mode = function()
  return { mode = mode, blocking = false }
end
vim.bo.filetype = "python"
dofile("lua/plugins/blink-cmp.lua").init()
vim.api.nvim_exec_autocmds("UIEnter", {})
vim.wait(250, function()
  return #loaded > 0
end)
assert(#loaded == 0, "Completion preparation interrupted insert mode")

mode = "n"
vim.api.nvim_exec_autocmds("ModeChanged", { pattern = "i:n" })
vim.wait(250, function()
  return #loaded > 0
end)
assert(#loaded == 0, "Missing dependency triggered idle installation")

plugins["friendly-snippets"]._.installed = true
vim.api.nvim_exec_autocmds("BufReadPost", { buffer = 0 })
assert(
  vim.wait(500, function()
    return #loaded > 0
  end),
  "Completion preparation did not resume"
)
assert(
  vim.deep_equal(loaded, { "blink.cmp", "minuet-ai.nvim" }),
  "Unavailable plugins loaded"
)

plugins["nvim-autopairs"]._.installed = true
vim.api.nvim_exec_autocmds("BufReadPost", { buffer = 0 })
assert(
  vim.wait(500, function()
    return #loaded == 3
  end),
  "Newly installed plugin did not load"
)
assert(loaded[3] == "nvim-autopairs", "Loaded plugin initialized twice")

vim.api.nvim_get_mode = original_mode
print("Completion idle checks passed")
