-- Custom textobject specs for mini.ai.
-- Kept separate to avoid a large nested table in the plugin config.
local M = {}

--- Wrap a treesitter spec so it returns nil instead of erroring
--- when no parser is available for the current buffer.
local function ts(captures, opts)
  return function(...)
    local ts_spec = require("mini.ai").gen_spec.treesitter(captures, opts)
    local ok, result = pcall(ts_spec, ...)
    if ok then
      return result
    end
  end
end

-- Treesitter-powered (needs parser + textobjects.scm queries)
M.F = ts({ a = "@function.outer", i = "@function.inner" })
M.c = ts({ a = "@class.outer", i = "@class.inner" })
M.o = ts({
  a = { "@conditional.outer", "@loop.outer" },
  i = { "@conditional.inner", "@loop.inner" },
})
M.B = ts({ a = "@block.outer", i = "@block.inner" })

--- Line: al = full line, il = trimmed (no leading/trailing whitespace)
function M.l(ai_type)
  local res = {}
  for i = 1, vim.api.nvim_buf_line_count(0) do
    local line = vim.fn.getline(i)
    local from_col = ai_type == "i" and (line:find("%S") or 1) or 1
    local to_col = math.max(#line, 1)
    table.insert(res, {
      from = { line = i, col = from_col },
      to = { line = i, col = to_col },
    })
  end
  return res
end

--- Entire buffer: ae = whole file, ie = without leading/trailing blank lines
function M.e(ai_type)
  local first = 1
  local last = vim.fn.line("$")
  if ai_type == "i" then
    while first <= last and vim.fn.getline(first):find("^%s*$") do
      first = first + 1
    end
    while last >= first and vim.fn.getline(last):find("^%s*$") do
      last = last - 1
    end
  end
  return {
    from = { line = first, col = 1 },
    to = { line = last, col = math.max(#vim.fn.getline(last), 1) },
  }
end

return M
