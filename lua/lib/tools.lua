local M = {}

---@class lib.tools.Tool
---@field name string
---@field bin string
---@field kind string

local function missing_tools(tools)
  local missing = {}
  for _, t in ipairs(tools) do
    if vim.fn.executable(t.bin) ~= 1 then
      table.insert(
        missing,
        string.format("  %s (%s): %s", t.kind, t.name, t.bin)
      )
    end
  end
  return missing
end

local function notify_missing(tools)
  local missing = missing_tools(tools)
  if #missing == 0 then
    return
  end

  vim.notify(
    "Missing tools:\n" .. table.concat(missing, "\n"),
    vim.log.levels.WARN
  )
end

--- Check tool binaries when a matching filetype is first opened.
--- @param ft string|string[] filetype(s) to trigger the check
--- @param tools lib.tools.Tool[]
function M.check(ft, tools)
  local group = vim.api.nvim_create_augroup(
    "ToolCheck_" .. (type(ft) == "table" and ft[1] or ft),
    {}
  )
  vim.api.nvim_create_autocmd("FileType", {
    pattern = ft,
    group = group,
    once = true,
    callback = function()
      notify_missing(tools)
    end,
  })
end

--- Check tool binaries immediately.
--- @param tools lib.tools.Tool[]
function M.check_now(tools)
  notify_missing(tools)
end

return M
