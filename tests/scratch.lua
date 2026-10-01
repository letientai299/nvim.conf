vim.opt.rtp:prepend(vim.fn.getcwd())

local scratch = require("lib.scratch")
local original_uis = vim.api.nvim_list_uis
local original_argc = vim.fn.argc
local requested, opened, pending, ready

package.loaded["lib.lazy_ondemand"] = {
  on_load = function(_, fn)
    if ready then
      fn()
    else
      pending = fn
    end
  end,
}
package.loaded["lazy"] = {
  load = function()
    requested = true
  end,
}
package.loaded["snacks"] = {
  scratch = function(opts)
    assert(
      opts.win.position == "current",
      "Scratch must replace startup buffer"
    )
    vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(false, true))
    opened = true
  end,
}

for _, case in ipairs({
  { name = "bare", opens = true },
  { name = "loaded", opens = true, loaded = true },
  { name = "file", argc = 1 },
  { name = "headless", headless = true },
  {
    name = "named",
    prepare = function()
      vim.api.nvim_buf_set_name(0, "startup-file")
    end,
  },
  {
    name = "edited",
    prepare = function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "note" })
    end,
  },
  {
    name = "special",
    prepare = function()
      vim.bo.buftype = "nofile"
    end,
  },
  {
    name = "delayed-edit",
    delayed = function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "keep this" })
    end,
  },
  {
    name = "delayed-switch",
    delayed = function()
      vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true, false))
    end,
  },
}) do
  vim.cmd("enew!")
  requested, opened, pending = false, false, nil
  ready = case.loaded
  vim.fn.argc = function()
    return case.argc or 0
  end
  vim.api.nvim_list_uis = function()
    return case.headless and {} or { {} }
  end
  if case.prepare then
    case.prepare()
  end
  local startup_buf = vim.api.nvim_get_current_buf()
  assert(
    dofile("lua/plugins/snacks.lua").lazy
      == (case.headless == true or (case.argc or 0) > 0),
    case.name .. ": eager loading"
  )
  scratch.setup()
  vim.api.nvim_exec_autocmds("VimEnter", {})
  vim.wait(20, function()
    return requested
  end)
  if case.delayed then
    assert(pending, case.name .. ": load was not queued")
    case.delayed()
  end
  if pending then
    pending()
  end
  assert(opened == (case.opens == true), case.name)
  assert(
    vim.api.nvim_buf_is_valid(startup_buf) ~= opened,
    case.name .. ": startup buffer cleanup"
  )
end

vim.api.nvim_list_uis = original_uis
vim.fn.argc = original_argc
print("Scratch startup checks passed")
