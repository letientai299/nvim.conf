return {
  "saghen/blink.cmp",
  version = "1.*",
  event = "InsertEnter",
  build = "cargo build --release",
  dependencies = {
    "L3MON4D3/LuaSnip",
    {
      dir = vim.fn.stdpath("config") .. "/plugins/blink-cmp-kitty",
      name = "blink-cmp-kitty",
    },
    {
      dir = vim.fn.stdpath("config") .. "/plugins/blink-cmp-path",
      name = "blink-cmp-path",
    },
  },
  opts = {
    keymap = { preset = "default" },
    signature = { enabled = true },
    completion = {
      ghost_text = { enabled = true },
      documentation = { auto_show = true },
      menu = {
        draw = {
          columns = {
            { "kind_icon" },
            { "label", "label_description", gap = 1 },
            { "source_name" },
          },
        },
      },
    },
    snippets = { preset = "luasnip" },
    sources = {
      default = { "lsp", "snippets", "path", "buffer" },
      per_filetype = {
        lua = { inherit_defaults = true, "lazydev" },
      },
      providers = {
        path = {
          score_offset = 100,
          opts = {
            show_hidden_files_by_default = true,
          },
        },
        lazydev = {
          name = "LazyDev",
          module = "lazydev.integrations.blink",
          score_offset = 100,
        },
        kitty_pane = {
          name = "kitty",
          module = "blink-cmp-kitty",
          score_offset = -3,
        },
        path_cwd = {
          name = "cwd",
          module = "blink-cmp-path",
          score_offset = 90,
          opts = {
            always_index = { ".ai.dump/**" },
          },
        },
      },
    },
    fuzzy = { implementation = "prefer_rust" },
  },
  config = function(_, opts)
    table.insert(opts.sources.default, "kitty_pane")
    table.insert(opts.sources.default, "path_cwd")

    local function get_disabled()
      return vim.b.blink_disabled_sources or {}
    end

    local function disable_source(id)
      local disabled = get_disabled()
      disabled[id] = true
      vim.b.blink_disabled_sources = disabled
    end

    local function reenable_sources(ids)
      local disabled = get_disabled()
      for _, id in ipairs(ids) do
        disabled[id] = nil
      end
      vim.b.blink_disabled_sources = disabled
    end

    -- Inject should_show_items into every provider
    for _, id in ipairs(opts.sources.default) do
      opts.sources.providers[id] = opts.sources.providers[id] or {}
      opts.sources.providers[id].should_show_items = function()
        local disabled = vim.b.blink_disabled_sources
        return not (disabled and disabled[id])
      end
    end

    -- <C-x><C-x>: disable source of the focused item, keep menu open
    opts.keymap["<C-x><C-x>"] = {
      function(cmp)
        local blink = require("blink.cmp")
        local item = blink.get_selected_item()
        if not item or not item.source_id then
          return
        end
        disable_source(item.source_id)
        cmp.hide()
        vim.schedule(function()
          blink.show()
        end)
      end,
    }

    -- <C-x><C-s>: picker to re-enable disabled sources (multi-select)
    opts.keymap["<C-x><C-s>"] = {
      function(cmp)
        local off = vim.tbl_keys(get_disabled())
        if #off == 0 then
          vim.notify("All sources are enabled", vim.log.levels.INFO)
          return
        end
        cmp.cancel()
        vim.cmd.stopinsert()
        vim.schedule(function()
          local has_fzf, fzf = pcall(require, "fzf-lua")
          if has_fzf then
            fzf.fzf_exec(off, {
              prompt = "Re-enable sources> ",
              fzf_opts = { ["--multi"] = true },
              actions = {
                ["default"] = function(selected)
                  reenable_sources(selected)
                end,
              },
            })
          else
            vim.ui.select(
              off,
              { prompt = "Re-enable source:" },
              function(choice)
                if choice then
                  reenable_sources({ choice })
                end
              end
            )
          end
        end)
      end,
    }

    require("blink.cmp").setup(opts)
  end,
}
