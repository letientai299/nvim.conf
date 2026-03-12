-- Slow linters excluded from InsertLeave (only run on BufWritePost/BufReadPost).
-- Lang files should add entries here for linters that are too slow for real-time.
local slow_linters = {
  golangcilint = true,
  ["markdownlint-cli2"] = true,
}

return {
  "mfussenegger/nvim-lint",
  event = { "BufWritePost", "BufReadPost", "InsertLeave" },
  opts = {
    linters_by_ft = {},
  },
  config = function(_, opts)
    local lint = require("lint")
    lint.linters_by_ft = opts.linters_by_ft

    -- Fast linters: InsertLeave + BufWritePost + BufReadPost
    -- Slow linters: BufWritePost + BufReadPost only
    vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost" }, {
      group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
      callback = function()
        lint.try_lint()
      end,
    })

    vim.api.nvim_create_autocmd("InsertLeave", {
      group = vim.api.nvim_create_augroup("nvim-lint-fast", { clear = true }),
      callback = function()
        local ft = vim.bo.filetype
        local names = lint.linters_by_ft[ft] or {}
        local fast = {}
        for _, name in ipairs(names) do
          if not slow_linters[name] then
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
