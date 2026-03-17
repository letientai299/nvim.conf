local M = {}

local NOTIFY_ID = "tool-installer"
local log = require("tool-installer.log")

---@param message string
---@param level integer
local function emit(message, level)
  log.append(level, message)
  vim.notify(message, level, { id = NOTIFY_ID, title = "tool-installer" })
end

---@class tool-installer.Progress
---@field total integer
---@field done integer
local Progress = {}
Progress.__index = Progress

---@param total integer
---@return tool-installer.Progress
function M.start(total)
  local self = setmetatable({ total = total, done = 0 }, Progress)
  emit("Installing " .. total .. " tool(s)...", vim.log.levels.INFO)
  return self
end

---@param name string
function Progress:installing(name)
  emit(
    "Installing " .. name .. "... (" .. self.done .. "/" .. self.total .. ")",
    vim.log.levels.INFO
  )
end

---@param name string
function Progress:installed(name)
  self.done = self.done + 1
  emit(
    name .. " ready (" .. self.done .. "/" .. self.total .. ")",
    vim.log.levels.INFO
  )
end

---@param name string
---@param err? string
function Progress:fail(name, err)
  self.done = self.done + 1
  emit(
    "Failed: " .. name .. (err and (": " .. err) or ""),
    vim.log.levels.ERROR
  )
end

function Progress:finish()
  emit("All tools processed.", vim.log.levels.INFO)
end

return M
