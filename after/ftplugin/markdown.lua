vim.bo.shiftwidth = 2
vim.bo.tabstop = 2
vim.bo.softtabstop = 2

local function toggle_line(lnum)
  local line = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1]
  if line:match("^(%s*)%- %[x%]") then
    line = line:gsub("^(%s*)%- %[x%]", "%1- [ ]")
  elseif line:match("^(%s*)%- %[ %]") then
    line = line:gsub("^(%s*)%- %[ %]", "%1- [x]")
  elseif line:match("^(%s*)%- ") then
    line = line:gsub("^(%s*)%- (.*)", "%1- [ ] %2")
  end
  vim.api.nvim_buf_set_lines(0, lnum - 1, lnum, false, { line })
end

vim.keymap.set("n", "<C-Space>", function()
  toggle_line(vim.fn.line("."))
end, { buffer = true, desc = "Toggle checklist" })

vim.keymap.set("x", "<C-Space>", function()
  local start = vim.fn.line("v")
  local stop = vim.fn.line(".")
  if start > stop then
    start, stop = stop, start
  end
  for lnum = start, stop do
    toggle_line(lnum)
  end
  vim.cmd("normal! \27") -- exit visual mode
end, { buffer = true, desc = "Toggle checklist" })

-- Highlight bold markers (**Answer:**, **Status:**, etc.) in Q&A / review files.
-- Extensible: add entries to `markers` to support new keyword-color pairs.

local ns = vim.api.nvim_create_namespace("md_review_markers")

-- Each marker: lua pattern that captures (full_match), highlight group, and
-- optional sub-classifiers for the text after the marker.
-- Lua pattern matches both **Keyword:** and **Keyword**: forms.
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
-- Lua patterns don't support alternation, so we match each keyword separately.
---@type {pat: string, keyword: string}[]
local lua_pats = {}
local vim_alts = {}
for keyword, _ in pairs(markers) do
  -- Matches **Keyword:** and **Keyword**:
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

local buf = vim.api.nvim_get_current_buf()
apply_highlights(buf, 0, -1)

-- Incremental: only re-highlight changed lines.
vim.api.nvim_buf_attach(buf, false, {
  on_lines = function(_, b, _, first, _, last)
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(b) then
        apply_highlights(b, first, last)
      end
    end)
  end,
})

vim.keymap.set("n", "<A-]>", function()
  vim.fn.search(vim_pat, "w")
end, { buffer = true, desc = "Next review marker" })

vim.keymap.set("n", "<A-[>", function()
  vim.fn.search(vim_pat, "bw")
end, { buffer = true, desc = "Prev review marker" })

-- Q: insert a fenced code block with cursor on the closing line
vim.keymap.set("n", "Q", function()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0, row, row, false, { "```", "", "```" })
  vim.api.nvim_win_set_cursor(0, { row + 2, 3 })
  vim.cmd("startinsert!")
end, { buffer = true, desc = "Insert code block" })
