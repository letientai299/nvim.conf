return {
  "folke/snacks.nvim",
  lazy = true,
  init = function()
    -- Queue notifications until snacks loads, then replay them
    local queue = {}
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.notify = function(msg, level, o)
      table.insert(queue, { msg = msg, level = level, opts = o })
      -- Trigger lazy-load on first notification
      if #queue == 1 then
        vim.schedule(function()
          require("lazy").load({ plugins = { "snacks.nvim" } })
          vim.schedule(function()
            for _, item in ipairs(queue) do
              vim.notify(item.msg, item.level, item.opts)
            end
            queue = nil ---@diagnostic disable-line: cast-local-type
          end)
        end)
      end
    end
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
