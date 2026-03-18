local lazy_require = require("lib.lazy_ondemand").lazy_require
local nav = require("lib.nav_keys")

--- Jump to the next (dir=1) or previous (dir=-1) fold region (section
--- headers and file items) across the entire buffer.
local function jump_fold(dir)
  local status = require("neogit.buffers.status").instance()
  if not status or not status.buffer then
    return
  end

  -- Collect .first line of every section and item into a sorted list.
  local targets = {}
  for _, section in ipairs(status.buffer.ui.item_index) do
    if section.first then
      targets[#targets + 1] = section.first
      for _, item in ipairs(section.items) do
        targets[#targets + 1] = item.first
      end
    end
  end
  table.sort(targets)

  local line = vim.api.nvim_win_get_cursor(0)[1]
  if dir == 1 then
    for _, t in ipairs(targets) do
      if t > line then
        status.buffer:move_cursor(t)
        return
      end
    end
  else
    for i = #targets, 1, -1 do
      if targets[i] < line then
        status.buffer:move_cursor(targets[i])
        return
      end
    end
  end
end

return {
  "NeogitOrg/neogit",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "sindrets/diffview.nvim",
    "letientai299/diffs.nvim",
  },
  keys = {
    {
      "<Leader>gg",
      function()
        lazy_require("neogit").open()
      end,
      desc = "Neogit status",
    },
    {
      "<Leader>gl",
      function()
        lazy_require("neogit").open({ "log" })
      end,
      desc = "Log (branch)",
    },
  },
  opts = {
    graph_style = "kitty",
    remember_settings = true,
    use_per_project_settings = true,
    integrations = { diffview = true },
    mappings = {
      status = {
        [nav.next] = false, -- replaced by buffer-local item jump below
        [nav.prev] = false,
      },
    },
  },
  config = function(_, opts)
    require("neogit").setup(opts)
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("NeogitItemJump", { clear = true }),
      pattern = "NeogitStatus",
      callback = function(ev)
        local o = { buffer = ev.buf }
        vim.keymap.set("n", nav.next, function()
          jump_fold(1)
        end, o)
        vim.keymap.set("n", nav.prev, function()
          jump_fold(-1)
        end, o)
      end,
    })
  end,
}
