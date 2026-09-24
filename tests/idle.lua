vim.opt.rtp:prepend(vim.fn.getcwd())

local idle = require("lib.idle")
local original_mode = vim.api.nvim_get_mode
local mode = "i"
vim.api.nvim_get_mode = function()
  return { mode = mode, blocking = false }
end

local results = {}
idle.schedule("replace", function()
  results[#results + 1] = "stale"
end)
idle.schedule("replace", function()
  results[#results + 1] = "updated"
end)
idle.schedule("cancel", function()
  results[#results + 1] = "cancelled"
end)
idle.cancel("cancel")

vim.wait(250, function()
  return #results > 0
end)
assert(#results == 0, "Idle work interrupted insert mode")

mode = "n"
vim.api.nvim_exec_autocmds("ModeChanged", { pattern = "i:n" })
assert(
  vim.wait(500, function()
    return #results > 0
  end),
  "Idle work failed to resume"
)
assert(results[1] == "updated", "Idle work used a stale callback")

idle.schedule("next", function()
  results[#results + 1] = "next"
  idle.schedule("nested", function()
    results[#results + 1] = "nested"
  end)
end)
assert(
  vim.wait(1000, function()
    return #results == 3
  end),
  "Nested idle work was lost"
)
assert(
  table.concat(results, ",") == "updated,next,nested",
  "Idle order changed"
)

vim.api.nvim_get_mode = original_mode
print("Idle scheduling checks passed")
