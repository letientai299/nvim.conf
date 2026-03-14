--- Headless plugin bootstrap.
---
--- Simulates an interactive startup so on-demand installs trigger for plugins
--- that would load in a normal session (VeryLazy, VimEnter, first buffer).
--- Used by scripts/install.sh to pre-install plugins without maintaining a
--- hard-coded list.
---
--- In --headless mode UIEnter never fires, so VeryLazy never triggers and
--- startup plugins never load. This module fires those events manually,
--- waits for all async clones to finish, then quits.

local M = {}

--- Run the bootstrap: fire startup events, wait for installs, quit.
function M.run()
  local lazy_dir = vim.fn.stdpath("data") .. "/lazy"

  -- UIEnter triggers the VeryLazy chain in lazy.nvim.
  vim.api.nvim_exec_autocmds("UIEnter", { modeline = false })

  -- Poll until no .cloning marker files remain (lazy.nvim creates
  -- <plugin-dir>.cloning during git-clone and removes it on success).
  vim.wait(300000, function()
    for name in vim.fs.dir(lazy_dir) do
      if name:match("%.cloning$") then
        return false
      end
    end
    return true
  end, 1000)

  vim.cmd("qa!")
end

return M
