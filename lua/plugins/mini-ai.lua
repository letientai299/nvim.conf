return {
  "echasnovski/mini.ai",
  dependencies = { { "nvim-treesitter/nvim-treesitter-textobjects", branch = "main" } },
  lazy = false,
  opts = function()
    local ai = require("mini.ai")
    local spec = ai.gen_spec.treesitter

    -- Wrap treesitter spec so it returns nil instead of erroring
    -- when no parser is available for the current buffer.
    local function ts(captures, opts)
      local ts_spec = spec(captures, opts)
      return function(...)
        local ok, result = pcall(ts_spec, ...)
        if ok then return result end
      end
    end

    return {
      -- Remap *_last to `L` so `il`/`al` work as textobject `l` (line).
      mappings = {
        around_last = "aL",
        inside_last = "iL",
      },
      custom_textobjects = {
        -- Treesitter-powered (needs parser + textobjects.scm queries)
        F = ts({ a = "@function.outer", i = "@function.inner" }),
        c = ts({ a = "@class.outer", i = "@class.inner" }),
        o = ts({
          a = { "@conditional.outer", "@loop.outer" },
          i = { "@conditional.inner", "@loop.inner" },
        }),
        B = ts({ a = "@block.outer", i = "@block.inner" }),

        -- Line: al = full line, il = trimmed (no leading/trailing whitespace)
        l = function(ai_type)
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
        end,

        -- Entire buffer: ae = whole file, ie = without leading/trailing blank lines
        e = function(ai_type)
          local first = 1
          local last = vim.fn.line("$")
          if ai_type == "i" then
            while first <= last and vim.fn.getline(first):find("^%s*$") do first = first + 1 end
            while last >= first and vim.fn.getline(last):find("^%s*$") do last = last - 1 end
          end
          return {
            from = { line = first, col = 1 },
            to = { line = last, col = math.max(#vim.fn.getline(last), 1) },
          }
        end,
      },
    }
  end,
}
