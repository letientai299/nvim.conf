local function lsp_active()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  local count = #clients
  if count == 0 then
    return ""
  end
  return "󰕥 " .. count
end

--- Detect CRLF or mixed line endings, cached per buffer.
local eol_cache = {} ---@type table<integer, string>

local function compute_line_endings(buf)
  if vim.bo[buf].fileformat == "dos" then
    return "CRLF"
  end
  return vim.api.nvim_buf_call(buf, function()
    if vim.fn.search("\r", "nw") == 0 then
      return ""
    end
    -- [^\r]$ matches lines whose last char is not \r (skips empty lines)
    return vim.fn.search("[^\r]$", "nw") > 0 and "MIXED" or "CRLF"
  end)
end

local function line_endings()
  local buf = vim.api.nvim_get_current_buf()
  local cached = eol_cache[buf]
  if cached ~= nil then
    return cached
  end
  if not vim.api.nvim_buf_is_loaded(buf) then
    return ""
  end
  local result = compute_line_endings(buf)
  eol_cache[buf] = result
  return result
end

vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "BufDelete" }, {
  callback = function(ev)
    eol_cache[ev.buf] = nil
  end,
})

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
          { line_endings, color = { fg = "#e0af68" } },
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
