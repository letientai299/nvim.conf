-- Slow linters excluded from InsertLeave (only run on BufWritePost).
-- Lang files should add entries here for linters that are too slow for real-time.
local slow_linters = {
  golangcilint = true,
}

local function is_available(name)
  local lint = require("lint")
  local linter = lint.linters[name]
  local cmd = linter and linter.cmd
  if type(cmd) == "function" then
    cmd = cmd()
  end
  return cmd ~= nil and vim.fn.executable(cmd) == 1
end

--- Filter a list of linter names to only those with an installed binary.
local function filter_available(names)
  local result = {}
  for _, name in ipairs(names) do
    if is_available(name) then
      result[#result + 1] = name
    end
  end
  return result
end

return {
  "mfussenegger/nvim-lint",
  event = { "BufWritePost", "InsertLeave" },
  opts = function()
    return {
      linters_by_ft = {},
    }
  end,
  config = function(_, opts)
    require("lib.lang_registry").activate_lint(opts)

    local lint = require("lint")
    lint.linters_by_ft = opts.linters_by_ft

    -- Run lint after writes; avoid adding initial file-open cost.
    vim.api.nvim_create_autocmd("BufWritePost", {
      group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
      callback = function()
        local ft = vim.bo.filetype
        local names = lint.linters_by_ft[ft] or {}
        local avail = filter_available(names)
        if #avail > 0 then
          lint.try_lint(avail)
        end
      end,
    })

    vim.api.nvim_create_autocmd("InsertLeave", {
      group = vim.api.nvim_create_augroup("nvim-lint-fast", { clear = true }),
      callback = function()
        local ft = vim.bo.filetype
        local names = lint.linters_by_ft[ft] or {}
        local fast = {}
        for _, name in ipairs(names) do
          if not slow_linters[name] and is_available(name) then
            fast[#fast + 1] = name
          end
        end
        if #fast > 0 then
          lint.try_lint(fast)
        end
      end,
    })
  end,
}
