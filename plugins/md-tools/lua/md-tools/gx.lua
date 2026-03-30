local M = {}

local image_exts =
  { png = true, jpg = true, jpeg = true, gif = true, svg = true, webp = true }

--- Scan buffer for a reference-link definition `[ref]: url`.
--- Handles both single-line and multi-line (URL on indented next line).
---@param ref string the reference label (case-insensitive)
---@return string? url
local function resolve_ref(ref)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local lower_ref = ref:lower()
  local esc = vim.pesc(lower_ref)
  for i, line in ipairs(lines) do
    local lower = line:lower()
    -- Single-line: [ref]: url
    local url = lower:match("^%[" .. esc .. "%]:%s+(.+)")
    if url then
      return vim.trim(line:match("^%[.-%]:%s+(.+)"))
    end
    -- Multi-line: [ref]: followed by indented URL on next line
    if lower:match("^%[" .. esc .. "%]:%s*$") and lines[i + 1] then
      local next = vim.trim(lines[i + 1])
      if next ~= "" then
        return next
      end
    end
  end
  return nil
end

--- Check if url points to an image by extension.
---@param url string
---@return boolean
local function is_image(url)
  local ext = url:match("%.(%w+)%s*$")
  return ext ~= nil and image_exts[ext:lower()] ~= nil
end

--- Open a URL or image path.
---@param url string
local function open(url)
  if is_image(url) and not url:match("^https?://") then
    -- Resolve relative paths against the buffer's directory.
    if not url:match("^/") then
      local buf_dir = vim.fn.expand("%:p:h")
      url = buf_dir .. "/" .. url
    end
    vim.fn.system({ "open", url })
  else
    vim.ui.open(url)
  end
end

--- Try to extract a markdown link at or near the cursor position.
--- Returns the resolved URL or nil.
---@return string?
local function resolve_link_at_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1 -- 1-based

  -- Definition line: [ref]: url
  local def_url = line:match("^%[.-%]:%s+(.+)")
  if def_url then
    return vim.trim(def_url)
  end

  -- Find all markdown links on the line and pick the one under cursor.
  -- Patterns: [text](url), [text][ref], [text][]
  -- Also handles image variants: ![text](url), ![text][ref]

  -- Inline link: [text](url) or ![text](url)
  for s, url, e in line:gmatch("()!?%[.-%]%((.-)%)()") do
    if col >= s and col < e then
      return url
    end
  end

  -- Reference link: [text][ref] or ![text][ref]
  for s, ref, e in line:gmatch("()!?%[.-%]%[(.-)%]()") do
    if col >= s and col < e then
      if ref == "" then
        -- Implicit reference: [text][] — use text as ref
        local text = line:sub(s):match("!?%[(.-)%]%[%]")
        return resolve_ref(text)
      end
      return resolve_ref(ref)
    end
  end

  -- Shortcut reference: [ref] alone (not followed by ( or [)
  -- Must not be a definition line (already handled above).
  for s, ref, e in line:gmatch("()%[(.-)%]()") do
    local after = line:sub(e, e)
    if
      col >= s
      and col < e
      and after ~= "("
      and after ~= "["
      and after ~= ":"
    then
      return resolve_ref(ref)
    end
  end

  return nil
end

function M.smart_gx()
  local url = resolve_link_at_cursor()
  if url then
    open(url)
  else
    -- Fall back to netrw's gx or vim.ui.open on <cfile>
    local cfile = vim.fn.expand("<cfile>")
    if cfile and cfile ~= "" then
      vim.ui.open(cfile)
    end
  end
end

function M.setup_keymaps()
  vim.keymap.set(
    "n",
    "gx",
    M.smart_gx,
    { buffer = true, desc = "Smart link open" }
  )
end

return M
