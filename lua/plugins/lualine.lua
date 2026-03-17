local function lsp_active()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  local count = #clients
  if count == 0 then
    return ""
  end
  return "󰕥 " .. count
end

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
        lualine_a = {
          {
            "buffers",
            show_filename_only = false,
            mode = 2,
          },
        },
        lualine_z = { "tabs" },
      },
      sections = {
        lualine_a = {
          {
            "mode",
            fmt = function(s)
              return s:sub(1, 1)
            end,
          },
        },
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
        lualine_c = { "aerial", "searchcount" },
        lualine_x = {
          { lsp_active },
          "diagnostics",
        },
        lualine_y = { "progress" },
        lualine_z = { "selectioncount", "location" },
      },
      extensions = { "oil", "toggleterm", "quickfix", "fzf", "lazy" },
    }
  end,
}
