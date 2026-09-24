local M = {}

local callbacks = {}
local queue = {}
local timer
local initialized = false
local last_key = 0
local delay = 150
local arm

local function run()
  timer = nil
  if vim.api.nvim_get_mode().mode ~= "n" then
    return
  end

  local remaining = delay - (vim.uv.hrtime() - last_key) / 1e6
  if remaining > 0 then
    arm(math.ceil(remaining))
    return
  end

  while #queue > 0 do
    local key = table.remove(queue, 1)
    local callback = callbacks[key]
    callbacks[key] = nil
    if callback then
      local ok, err = xpcall(callback, debug.traceback)
      if not ok then
        vim.notify(err, vim.log.levels.ERROR)
      end
      break
    end
  end

  if next(callbacks) then
    arm(delay)
  end
end

arm = function(wait)
  if not timer and next(callbacks) then
    timer = vim.defer_fn(run, wait)
  end
end

local function setup()
  if initialized then
    return
  end
  initialized = true
  local group = vim.api.nvim_create_augroup("IdleWork", { clear = true })
  vim.on_key(function()
    last_key = vim.uv.hrtime()
    arm(delay)
  end, vim.api.nvim_create_namespace("IdleWork"))
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = group,
    callback = function()
      arm(delay)
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      if timer and not timer:is_closing() then
        timer:stop()
        timer:close()
        timer = nil
      end
    end,
  })
end

function M.schedule(key, callback)
  setup()
  if not callbacks[key] then
    queue[#queue + 1] = key
  end
  callbacks[key] = callback
  arm(delay)
end

function M.cancel(key)
  callbacks[key] = nil
end

return M
