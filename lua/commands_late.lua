-- Deferred commands and autocmds that are not needed for the first painted
-- frame.

-- ---------------------------------------------------------------------------
-- Commands
-- ---------------------------------------------------------------------------

vim.api.nvim_create_user_command("SudoWrite", function()
  vim.cmd("w !sudo tee % > /dev/null")
  vim.cmd.edit({ bang = true })
end, { desc = "Write file with sudo" })

do
  local config_dir = vim.fn.stdpath("config")

  local function source_if_exists(path)
    if vim.uv.fs_stat(path) then
      vim.cmd.source(path)
    end
  end

  --- Read persisted theme state and apply if the colorscheme changed.
  --- Returns the new colorscheme name, or nil.
  local function reload_theme()
    local state_path = vim.fn.stdpath("state") .. "/store/theme.lua"
    if not vim.uv.fs_stat(state_path) then
      return
    end

    local ok, entry = pcall(function()
      return require("lib.bytecache").load(state_path)
    end)
    if not ok or not entry or not entry.colorscheme then
      return
    end
    if entry.colorscheme == (vim.g.colors_name or "") then
      return
    end

    -- Ensure the owning plugin is loaded before applying.
    if entry.plugin and entry.plugin ~= "" then
      pcall(function()
        require("lazy.core.loader").load(
          { entry.plugin },
          { cmd = "colorscheme" }
        )
      end)
    end

    local aok, aerr = pcall(function()
      require("store-theme").apply(entry, false)
    end)
    if not aok then
      vim.notify("Reload: theme apply failed: " .. aerr, vim.log.levels.WARN)
      return
    end
    return entry.colorscheme
  end

  vim.api.nvim_create_user_command("Reload", function(opts)
    -- Reload a specific lazy.nvim plugin by name.
    if opts.args ~= "" then
      local ok, loader = pcall(require, "lazy.core.loader")
      if not ok then
        vim.notify("Reload: lazy.nvim loader unavailable", vim.log.levels.ERROR)
        return
      end
      loader.reload(opts.args)
      vim.notify("Reloaded plugin: " .. opts.args)
      return
    end

    -- 1. Clear module cache for config modules and local plugins.
    local cleared = 0
    for mod, _ in pairs(package.loaded) do
      local found = vim.loader.find(mod)
      local path = found[1] and found[1].modpath
      if path and path:find(config_dir, 1, true) then
        package.loaded[mod] = nil
        cleared = cleared + 1
      end
    end

    -- 2. Invalidate vim.loader bytecode cache.
    vim.loader.reset()

    -- 3. Re-require core modules (keymaps/commands pull in _late variants
    --    because vim.v.vim_did_enter == 1 at reload time).
    for _, mod in ipairs({ "options", "keymaps", "commands" }) do
      local ok, err = pcall(require, mod)
      if not ok then
        vim.notify(
          "Reload failed (" .. mod .. "): " .. err,
          vim.log.levels.ERROR
        )
        return
      end
    end

    -- 4. Re-source local config and project exrc.
    source_if_exists(config_dir .. "/lua/local/init.lua")
    source_if_exists(vim.fn.getcwd() .. "/.nvim.lua")

    -- 5. Reload theme from persisted state if it changed.
    local theme = reload_theme()
    local suffix = theme and (", theme → " .. theme) or ""
    vim.notify(string.format("Reloaded %d modules%s", cleared, suffix))
  end, {
    nargs = "?",
    complete = function()
      local ok, cfg = pcall(require, "lazy.core.config")
      if not ok then
        return {}
      end
      return vim.tbl_keys(cfg.plugins)
    end,
    desc = "Reload config modules, theme, or a specific plugin",
  })
end

vim.api.nvim_create_user_command("W", function()
  vim.cmd("noautocmd write")
end, { desc = "Write file without formatting" })

vim.api.nvim_create_user_command("AutoFormat", function()
  require("conform").format({ async = true, lsp_fallback = true })
end, { desc = "Format current buffer with conform.nvim" })

vim.api.nvim_create_user_command("LocalTodo", function()
  local git_dir =
    vim.fn.system("git rev-parse --git-common-dir 2>/dev/null"):gsub("%s+$", "")
  if vim.v.shell_error ~= 0 or git_dir == "" then
    vim.notify("Not a git repo", vim.log.levels.ERROR)
    return
  end
  local repo = vim.fn.fnamemodify(git_dir, ":h")
  vim.fn.mkdir(repo .. "/.dump", "p")
  vim.cmd.edit(repo .. "/.dump/todo.md")
end, { desc = "Open per-repo todo file at .dump/todo.md" })

vim.api.nvim_create_user_command("BufOnly", function()
  local cur = vim.api.nvim_get_current_buf()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= cur and vim.bo[buf].buflisted then
      vim.api.nvim_buf_delete(buf, {})
    end
  end
end, { desc = "Close all buffers except current" })

-- ---------------------------------------------------------------------------
-- Autocmds
-- ---------------------------------------------------------------------------

local augroup = vim.api.nvim_create_augroup("UserConfig", { clear = true })

-- Trigger autoread when focus returns or buffer is entered.
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
  group = augroup,
  command = "silent! checktime",
})

-- Warn when a file changes on disk.
vim.api.nvim_create_autocmd("FileChangedShellPost", {
  group = augroup,
  callback = function()
    vim.notify("File changed on disk. Buffer reloaded.", vim.log.levels.WARN)
  end,
})

-- Hide end-of-buffer tildes after colorscheme loads.
vim.api.nvim_create_autocmd("ColorScheme", {
  group = augroup,
  callback = function()
    local bg = vim.api.nvim_get_hl(0, { name = "Normal" }).bg
    if bg then
      vim.api.nvim_set_hl(0, "EndOfBuffer", { fg = bg })
    end
  end,
})

-- Markdown: enable proper comment leaders for lists and quotes.
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  group = augroup,
  pattern = "*.md",
  callback = function()
    vim.opt_local.comments = "fb:>,fb:*,fb:+,fb:-"
  end,
})

-- Azure DevOps Definitions files → confini filetype.
vim.api.nvim_create_autocmd("BufEnter", {
  group = augroup,
  pattern = "*Definitions.*",
  callback = function()
    vim.bo.filetype = "confini"
  end,
})

-- ---------------------------------------------------------------------------
-- Abbreviations
-- ---------------------------------------------------------------------------

vim.cmd.iabbrev("ref refactor:")
vim.cmd.iabbrev("ans **Answer**:")
