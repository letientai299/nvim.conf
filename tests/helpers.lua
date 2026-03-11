local M = {}

local MiniTest = require("mini.test")

--- Repo root (absolute, no trailing slash).
M.root = vim.fn.fnamemodify(".", ":p"):gsub("/$", "")

--- Assert equality.
M.eq = MiniTest.expect.equality

--- Create isolated XDG dirs and install plugins once.
--- Returns a context table; pass it to new_child() and teardown().
function M.setup()
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp .. "/config", "p")
  vim.fn.mkdir(tmp .. "/data", "p")
  vim.fn.mkdir(tmp .. "/state", "p")
  vim.fn.mkdir(tmp .. "/cache", "p")
  vim.uv.fs_symlink(M.root, tmp .. "/config/nvim")

  local ctx = {
    tmp = tmp,
    init = tmp .. "/config/nvim/init.lua",
    env = {
      XDG_CONFIG_HOME = tmp .. "/config",
      XDG_DATA_HOME = tmp .. "/data",
      XDG_STATE_HOME = tmp .. "/state",
      XDG_CACHE_HOME = tmp .. "/cache",
      NVIM_TEST = "1",
    },
  }

  -- Install plugins once so per-case restarts are fast.
  local child = M.new_child(ctx)
  child.lua([[
    local lazy = require("lazy")
    lazy.install({ show = false })
    vim.wait(60000, function()
      for _, p in ipairs(lazy.plugins()) do
        if not p._.installed then return false end
      end
      return true
    end, 200)
  ]])
  child.stop()
  return ctx
end

--- Spawn a fresh child Neovim using an existing context.
function M.new_child(ctx)
  local child = MiniTest.new_child_neovim()

  -- Temporarily set env so the child inherits it.
  local saved = {}
  for k, _ in pairs(ctx.env) do saved[k] = vim.env[k] end
  for k, v in pairs(ctx.env) do vim.env[k] = v end

  child.restart({ "-u", ctx.init })

  for k, v in pairs(saved) do vim.env[k] = v end
  return child
end

--- Remove temp dirs.
function M.teardown(ctx)
  if ctx and ctx.tmp then vim.fn.delete(ctx.tmp, "rf") end
end

return M
