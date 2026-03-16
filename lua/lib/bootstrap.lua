--- Headless plugin bootstrap.
---
--- Pre-installs a curated set of startup-essential plugins in --headless mode
--- so the first interactive launch has a good UX:
---
---   nvim         → mini.starter (greeter)
---   nvim <dir>   → oil.nvim (file browser)
---   nvim <file>  → catppuccin (theme) + nvim-treesitter (highlighting)
---   any start    → mini.clue (key hints)
---
--- Catppuccin is installed by init.lua's colorscheme block before this runs.
--- Command-, key-, and filetype-specific plugins install on first real use.
---
--- Used by scripts/install.sh to bootstrap a fresh deployment.

local M = {}

--- Load essential plugins, wait for async installs, then quit.
function M.run()
  local lazy_dir = vim.fn.stdpath("data") .. "/lazy"

  -- Explicitly load the curated plugin set. For uninstalled plugins,
  -- lazy_ondemand's patched _load starts async clones automatically.
  -- Catppuccin is already handled by init.lua's colorscheme block.
  require("lazy").load({
    plugins = {
      "mini.clue",
      "mini.starter",
      "oil.nvim",
      "nvim-treesitter",
    },
  })

  -- Poll until no .cloning marker files remain (lazy.nvim creates
  -- <plugin-dir>.cloning during git-clone and removes it on success).
  local timeout = tonumber(vim.env.NVIM_BOOTSTRAP_TIMEOUT) or 60000
  vim.wait(timeout, function()
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
