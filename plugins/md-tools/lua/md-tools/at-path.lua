--- Auto-wrap bare @path/to/file references in backticks on save.
--- Runs after formatters (BufWritePost) to fix escaped underscores.
local M = {}

-- Matches a bare @path that looks like a file reference (must contain a slash).
-- Allows backslash-escaped underscores (\_) that prettier inserts.
-- Simple @username mentions are left alone.
local AT_PATH = "@[%w_\\%.%-]+/[%w_\\%.%-/]+"

--- Wrap bare @path references in backticks within the given line.
--- Also un-escapes \_  back to _ inside the wrapped span.
--- Skips paths already inside inline code spans.
---@param line string
---@return string, integer -- modified line, number of replacements
function M.wrap_line(line)
  -- Split line into segments: backtick-delimited code spans vs plain text.
  -- Only transform plain-text segments.
  local parts = {}
  local n = 0
  local pos = 1
  while pos <= #line do
    local tick_start = line:find("`", pos, true)
    if not tick_start then
      parts[#parts + 1] = { text = line:sub(pos), code = false }
      break
    end
    if tick_start > pos then
      parts[#parts + 1] = { text = line:sub(pos, tick_start - 1), code = false }
    end
    local tick_end = line:find("`", tick_start + 1, true)
    if not tick_end then
      parts[#parts + 1] = { text = line:sub(tick_start), code = false }
      break
    end
    parts[#parts + 1] = { text = line:sub(tick_start, tick_end), code = true }
    pos = tick_end + 1
  end

  for i, part in ipairs(parts) do
    if not part.code then
      local new, count = part.text:gsub(AT_PATH, function(m)
        -- Un-escape \_ → _ inside the path, then wrap in backticks.
        return "`" .. m:gsub("\\_", "_") .. "`"
      end)
      parts[i].text = new
      n = n + count
    end
  end

  local result = {}
  for _, part in ipairs(parts) do
    result[#result + 1] = part.text
  end
  return table.concat(result), n
end

--- Compute wrapped lines without modifying the buffer.
---@param buf integer
---@return string[]? new_lines, integer total replacements
local function compute_wrapped(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local total = 0
  local in_fence = false

  for i, line in ipairs(lines) do
    if line:match("^%s*```") then
      in_fence = not in_fence
    elseif not in_fence then
      local new, count = M.wrap_line(line)
      if count > 0 then
        lines[i] = new
        total = total + count
      end
    end
  end

  if total == 0 then
    return nil, 0
  end
  return lines, total
end

function M.setup(buf)
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = vim.api.nvim_create_augroup(
      "md-tools-at-path-" .. buf,
      { clear = true }
    ),
    buffer = buf,
    callback = function(ev)
      local b = ev.buf
      local lines = compute_wrapped(b)
      if not lines then
        return
      end
      -- Apply + save without polluting undo history.
      local ul = vim.bo[b].undolevels
      vim.bo[b].undolevels = -1
      vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
      vim.cmd("noautocmd write")
      vim.bo[b].undolevels = ul
    end,
  })
end

return M
