local M = {}

local NOTIFY_ID = "tool-installer"

---@class tool-installer.Progress
---@field total integer
---@field done integer
local Progress = {}
Progress.__index = Progress

---@param total integer
---@return tool-installer.Progress
function M.start(total)
  local self = setmetatable({ total = total, done = 0 }, Progress)
  vim.notify(
    "Installing " .. total .. " tool(s)...",
    vim.log.levels.INFO,
    { id = NOTIFY_ID, title = "tool-installer" }
  )
  return self
end

---@param name string
function Progress:installing(name)
  vim.notify(
    "Installing " .. name .. "... (" .. self.done .. "/" .. self.total .. ")",
    vim.log.levels.INFO,
    { id = NOTIFY_ID, title = "tool-installer" }
  )
end

---@param name string
function Progress:installed(name)
  self.done = self.done + 1
  vim.notify(
    name .. " ready (" .. self.done .. "/" .. self.total .. ")",
    vim.log.levels.INFO,
    { id = NOTIFY_ID, title = "tool-installer" }
  )
end

---@param name string
---@param err? string
function Progress:fail(name, err)
  self.done = self.done + 1
  vim.notify(
    "Failed: " .. name .. (err and (": " .. err) or ""),
    vim.log.levels.ERROR,
    { id = NOTIFY_ID, title = "tool-installer" }
  )
end

function Progress:finish()
  vim.notify("All tools processed.", vim.log.levels.INFO, {
    id = NOTIFY_ID,
    title = "tool-installer",
  })
end

return M
