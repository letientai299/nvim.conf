local M = {}

local ns = vim.api.nvim_create_namespace("md_review_markers")

---@class MdMarker
---@field hl string default highlight group
---@field sub? table<string, string> lowercased prefix → highlight group

---@type table<string, MdMarker>
local markers = {
  Answer = { hl = "DiagnosticInfo" },
  Status = {
    hl = "DiagnosticError", -- default = open/unfixed
    sub = {
      ["fixed"] = "DiagnosticOk",
      ["won't fix"] = "Comment",
      ["wont fix"] = "Comment",
      ["deferred"] = "DiagnosticWarn",
    },
  },
}

-- Pre-build per-keyword lua patterns and a single vim regex for jumping.
---@type {pat: string, keyword: string}[]
local lua_pats = {}
local vim_alts = {}
for keyword, _ in pairs(markers) do
  lua_pats[#lua_pats + 1] = {
    pat = "%*%*" .. keyword .. ":?%*%*%s*:?",
    keyword = keyword,
  }
  vim_alts[#vim_alts + 1] = keyword
end
table.sort(vim_alts)
local vim_pat = [[\*\*\(]]
  .. table.concat(vim_alts, [[:\?\|]])
  .. [[:\?\)\*\*\s*:\?]]

local function classify(marker, rest)
  if not marker.sub then
    return marker.hl
  end
  local lower = rest:lower()
  for prefix, hl in pairs(marker.sub) do
    if lower:find("^" .. prefix) then
      return hl
    end
  end
  return marker.hl
end

local function apply_highlights(buf, first, last)
  vim.api.nvim_buf_clear_namespace(buf, ns, first, last)
  local lines = vim.api.nvim_buf_get_lines(buf, first, last, false)
  for i, line in ipairs(lines) do
    for _, m in ipairs(lua_pats) do
      local s, e = line:find(m.pat)
      if s then
        local marker = markers[m.keyword]
        local rest = vim.trim(line:sub(e + 1))
        local hl = classify(marker, rest)
        local hl_end = marker.sub and #line or e
        vim.api.nvim_buf_add_highlight(
          buf,
          ns,
          hl,
          first + i - 1,
          s - 1,
          hl_end
        )
        break -- one marker per line
      end
    end
  end
end

local attached = {} ---@type table<integer, true>

function M.setup(buf)
  apply_highlights(buf, 0, -1)

  if attached[buf] then
    return
  end
  attached[buf] = true

  -- Incremental: only re-highlight changed lines.
  vim.api.nvim_buf_attach(buf, false, {
    on_lines = function(_, b, _, first, _, last)
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(b) then
          apply_highlights(b, first, last)
        end
      end)
    end,
    on_detach = function(_, b)
      attached[b] = nil
    end,
  })
end

function M.setup_keymaps()
  vim.keymap.set("n", "<A-]>", function()
    vim.fn.search(vim_pat, "w")
  end, { buffer = true, desc = "Next review marker" })

  vim.keymap.set("n", "<A-[>", function()
    vim.fn.search(vim_pat, "bw")
  end, { buffer = true, desc = "Prev review marker" })
end

return M
