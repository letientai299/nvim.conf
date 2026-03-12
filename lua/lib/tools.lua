local M = {}

--- @class lib.tools.Tool
--- @field name string
--- @field bin string
--- @field kind string

--- Check tool binaries when a matching filetype is first opened.
--- @param ft string|string[] filetype(s) to trigger the check
--- @param tools lib.tools.Tool[]
function M.check(ft, tools)
  local group = vim.api.nvim_create_augroup("ToolCheck_" .. (type(ft) == "table" and ft[1] or ft), {})
  vim.api.nvim_create_autocmd("FileType", {
    pattern = ft,
    group = group,
    once = true,
    callback = function()
      local missing = {}
      for _, t in ipairs(tools) do
        if vim.fn.executable(t.bin) ~= 1 then
          table.insert(missing, string.format("  %s (%s): %s", t.kind, t.name, t.bin))
        end
      end
      if #missing > 0 then
        vim.notify(
          "Missing tools:\n" .. table.concat(missing, "\n"),
          vim.log.levels.WARN
        )
      end
    end,
  })
end

return M
