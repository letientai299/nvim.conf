return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  opts = function()
    return {
      options = {
        globalstatus = true,
        section_separators = "",
        component_separators = "",
      },
      tabline = {
        lualine_a = { { "buffers", show_filename_only = true, mode = 2 } },
        lualine_z = { "tabs" },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = {
          "branch",
          {
            "diff",
            source = function()
              local gs = vim.b.gitsigns_status_dict
              if not gs then
                return nil
              end
              return {
                added = gs.added,
                modified = gs.changed,
                removed = gs.removed,
              }
            end,
          },
        },
        lualine_c = { { "filename", path = 1 }, "aerial", "searchcount" },
        lualine_x = {
          { "lsp_status", symbols = { done = "", separator = " " } },
          "diagnostics",
        },
        lualine_y = { "filetype" },
        lualine_z = { "selectioncount", "location" },
      },
      extensions = { "oil", "toggleterm", "quickfix", "fzf", "lazy" },
    }
  end,
}
