return {
  "folke/snacks.nvim",
  lazy = true,
  init = function()
    -- Queue notifications until snacks loads, then replay them.
    -- With on-demand plugin install, snacks may not be available immediately
    -- after require("lazy").load() — it may be cloning async. In that case,
    -- keep queueing and replay once snacks is loaded (via LazyLoad event).
    local queue = {}
    local load_requested = false

    local function replay()
      if not package.loaded["snacks"] or not queue then
        return
      end
      local items = queue
      queue = nil ---@diagnostic disable-line: cast-local-type
      for _, item in ipairs(items) do
        vim.notify(item.msg, item.level, item.opts)
      end
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    vim.notify = function(msg, level, o)
      if not queue then
        -- snacks already loaded and replayed; this is the real vim.notify
        -- from snacks. Shouldn't happen, but guard anyway.
        return
      end
      table.insert(queue, { msg = msg, level = level, opts = o })
      if not load_requested then
        load_requested = true
        vim.schedule(function()
          require("lazy").load({ plugins = { "snacks.nvim" } })
          vim.schedule(replay)
        end)
      end
    end

    -- Replay when snacks finishes async install + load.
    vim.api.nvim_create_autocmd("User", {
      pattern = "LazyLoad",
      callback = function(ev)
        if ev.data == "snacks.nvim" then
          vim.schedule(replay)
          return true -- remove this autocmd
        end
      end,
    })
  end,
  config = function(_, opts)
    require("snacks").setup(opts)
    vim.api.nvim_create_user_command("Notifications", function()
      require("snacks").notifier.show_history()
    end, {})
  end,
  keys = {
    {
      "<Leader>go",
      function()
        require("snacks").gitbrowse()
      end,
      mode = { "n", "v" },
      desc = "Open in browser",
    },
    {
      "<Leader>gO",
      function()
        require("snacks").gitbrowse({
          open = function(url)
            vim.fn.setreg("+", url)
            vim.notify("Copied: " .. url, vim.log.levels.INFO)
          end,
        })
      end,
      mode = { "n", "v" },
      desc = "Copy git URL",
    },
    {
      "<Leader>.",
      function()
        require("snacks").scratch()
      end,
      desc = "Toggle scratch buffer",
    },
    {
      "<Leader>,",
      function()
        require("snacks").scratch.select()
      end,
      desc = "Select scratch buffer",
    },
  },
  opts = function()
    return {
      notifier = {
        enabled = true,
        style = "minimal",
      },
      gitbrowse = { enabled = true },
      input = { enabled = true },
      scratch = {
        enabled = true,
        ft = "markdown",
      },
    }
  end,
}
