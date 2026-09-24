local M = {}

local function format_blocks(self, ctx, lines, callback)
  local formatter = require("conform.formatters.injected")
  -- Formatter scratch files must not start LSPs.
  local ignored = vim.o.eventignore
  vim.opt.eventignore:append("FileType")
  local ok, err = pcall(formatter.format, self, ctx, lines, callback)
  vim.o.eventignore = ignored
  if not ok then
    error(err, 0)
  end
end

function M.condition(self, ctx)
  -- Folded YAML scalars lose shell indentation.
  if vim.bo[ctx.buf].filetype:match("^yaml") then
    return false
  end
  return require("conform.formatters.injected").condition(self, ctx)
end

function M.format(self, ctx, lines, callback)
  local original = vim.api.nvim_buf_get_lines(ctx.buf, 0, -1, false)
  if vim.deep_equal(original, lines) then
    return format_blocks(self, ctx, lines, callback)
  end

  -- Earlier formatters can shift injection ranges.
  local buf = vim.api.nvim_create_buf(false, true)
  local filename = vim.api.nvim_buf_get_name(ctx.buf)
  if filename ~= "" then
    vim.api.nvim_buf_set_name(buf, filename .. ".nvim-injected-" .. buf)
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.cmd(
    ("noautocmd lua vim.bo[%d].filetype = %q"):format(
      buf,
      vim.bo[ctx.buf].filetype
    )
  )
  for _, option in ipairs({ "tabstop", "shiftwidth", "expandtab", "eol" }) do
    vim.bo[buf][option] = vim.bo[ctx.buf][option]
  end
  local finished = false
  local function finish(err, result)
    if finished then
      return
    end
    finished = true
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    callback(err, result)
  end
  local context = vim.tbl_extend("force", ctx, { buf = buf })
  local ok, err = pcall(format_blocks, self, context, lines, finish)
  if not ok then
    finish(err)
  end
end

return M
