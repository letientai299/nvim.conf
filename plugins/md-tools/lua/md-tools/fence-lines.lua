--- Darken the background of fence lines selected by a dirsv line range:
---
---     ```c:line-numbers {5,1-3}
---
--- Numbers are 1-based over the fence content, matching how dirsv (and Shiki)
--- number the rendered block, so `{5}` is the fifth line of code rather than
--- the fifth line of the buffer.
---
--- Syntax highlighting inside such fences is handled separately, by
--- after/queries/markdown/injections.scm.
local M = {}

local api = vim.api
local ns = api.nvim_create_namespace("md_fence_lines")
local HL = "MdFenceLine"
local DEBOUNCE_MS = 80

--- dirsv anchors this on whitespace (LINE_RANGE_META in rehype-line-numbers.ts).
--- Matching anywhere is equivalent in practice because non-numeric items are
--- discarded below, same as dirsv does.
local RANGE_PAT = "{([^{}]+)}"

local query ---@type vim.treesitter.Query?

local function get_query()
  if query == nil then
    local ok, parsed = pcall(
      vim.treesitter.query.parse,
      "markdown",
      [[
        (fenced_code_block
          (info_string) @info
          (code_fence_content) @content)
      ]]
    )
    query = ok and parsed or false
  end
  return query or nil
end

--- Parse a `{5,1-3}` list into a set of 1-based content line numbers.
---@param info string
---@return table<integer, true>?
local function selected_lines(info)
  local list = info:match(RANGE_PAT)
  if not list then
    return nil
  end

  local set = {}
  for item in vim.gsplit(list, ",", { trimempty = true }) do
    local first, last = vim.trim(item):match("^(%d+)%-(%d+)$")
    if not first then
      first = vim.trim(item):match("^(%d+)$")
      last = first
    end
    if first then
      -- A descending range selects nothing, as in dirsv.
      for n = tonumber(first), tonumber(last) do
        if n > 0 then
          set[n] = true
        end
      end
    end
  end

  return next(set) and set or nil
end

---@param buf integer
local function apply(buf)
  api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local q = get_query()
  if not q then
    return
  end

  local ok, parser = pcall(vim.treesitter.get_parser, buf)
  if not ok or not parser or parser:lang() ~= "markdown" then
    return
  end

  local info_id, content_id
  for id, name in ipairs(q.captures) do
    if name == "info" then
      info_id = id
    elseif name == "content" then
      content_id = id
    end
  end

  for _, tree in ipairs(parser:parse(true)) do
    for _, match in q:iter_matches(tree:root(), buf) do
      local info_node = match[info_id] and match[info_id][1]
      local content_node = match[content_id] and match[content_id][1]
      if info_node and content_node then
        local set = selected_lines(vim.treesitter.get_node_text(info_node, buf))
        if set then
          local first_row, _, end_row, end_col = content_node:range()
          -- The content node ends at column 0 of the closing delimiter line.
          local last_row = end_col == 0 and end_row - 1 or end_row
          for n in pairs(set) do
            local row = first_row + n - 1
            if row <= last_row then
              api.nvim_buf_set_extmark(buf, ns, row, 0, { line_hl_group = HL })
            end
          end
        end
      end
    end
  end
end

---@param rgb integer
---@param other integer
---@param alpha number weight of `other`, 0..1
---@return integer
local function blend(rgb, other, alpha)
  local out = 0
  for _, shift in ipairs({ 65536, 256, 1 }) do
    local a = math.floor(rgb / shift) % 256
    local b = math.floor(other / shift) % 256
    local mixed = math.floor(a * (1 - alpha) + b * alpha + 0.5)
    out = out + math.min(255, math.max(0, mixed)) * shift
  end
  return out
end

--- Themes that leave Normal transparent give us nothing to blend against, so
--- fall back to whatever group the theme does shade whole lines with.
local function base_bg()
  for _, name in ipairs({ "Normal", "CursorLine", "Visual" }) do
    local bg = api.nvim_get_hl(0, { name = name, link = false }).bg
    if bg then
      return bg
    end
  end
  return nil
end

local function define_hl()
  local bg = base_bg()
  if not bg then
    api.nvim_set_hl(0, HL, {
      bg = vim.o.background == "light" and 0xdcdcdc or 0x303030,
    })
    return
  end

  local r = math.floor(bg / 65536) % 256
  local g = math.floor(bg / 256) % 256
  local b = bg % 256
  local lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255

  local shaded
  if lum > 0.5 then
    shaded = blend(bg, 0x000000, 0.06) -- light theme: a hint of grey
  elseif lum > 0.08 then
    shaded = blend(bg, 0x000000, 0.38)
  else
    -- Already near black, so darkening would be invisible.
    shaded = blend(bg, 0xffffff, 0.10)
  end

  api.nvim_set_hl(0, HL, { bg = shaded })
end

local attached = {} ---@type table<integer, true>
local timers = {} ---@type table<integer, uv.uv_timer_t>
local hl_registered = false

---@param buf integer
local function schedule(buf)
  local timer = timers[buf]
  if not timer then
    timer = assert(vim.uv.new_timer())
    timers[buf] = timer
  end
  timer:stop()
  timer:start(
    DEBOUNCE_MS,
    0,
    vim.schedule_wrap(function()
      if api.nvim_buf_is_valid(buf) then
        apply(buf)
      end
    end)
  )
end

---@param buf integer
local function release(buf)
  local timer = timers[buf]
  if timer then
    timer:stop()
    if not timer:is_closing() then
      timer:close()
    end
    timers[buf] = nil
  end
  attached[buf] = nil
end

function M.setup(buf)
  if not hl_registered then
    hl_registered = true
    define_hl()
    api.nvim_create_autocmd("ColorScheme", {
      group = api.nvim_create_augroup("md-tools-fence-lines", { clear = true }),
      callback = define_hl,
    })
  end

  apply(buf)

  if attached[buf] then
    return
  end
  attached[buf] = true

  -- Editing the info string or inserting a line shifts every subsequent
  -- selection, so refresh the whole buffer rather than the changed range.
  api.nvim_buf_attach(buf, false, {
    on_lines = function(_, b)
      schedule(b)
    end,
    on_detach = function(_, b)
      release(b)
    end,
    on_reload = function(_, b)
      schedule(b)
    end,
  })
end

return M
