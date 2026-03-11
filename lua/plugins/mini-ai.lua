return {
  "echasnovski/mini.ai",
  dependencies = { { "nvim-treesitter/nvim-treesitter-textobjects", branch = "main" } },
  lazy = false,
  opts = function()
    local spec = require("mini.ai").gen_spec.treesitter
    return {
      custom_textobjects = {
        -- Treesitter-powered (needs textobjects.scm queries)
        F = spec({ a = "@function.outer", i = "@function.inner" }),
        c = spec({ a = "@class.outer", i = "@class.inner" }),
        o = spec({
          a = { "@conditional.outer", "@loop.outer" },
          i = { "@conditional.inner", "@loop.inner" },
        }),
        B = spec({ a = "@block.outer", i = "@block.inner" }),

        -- Line: al = full line, il = trimmed (no leading/trailing whitespace)
        l = function(ai_type)
          local line_num = vim.fn.line(".")
          local line = vim.fn.getline(line_num)
          local from_col = ai_type == "i" and (line:find("%S") or 1) or 1
          local to_col = #line
          return {
            from = { line = line_num, col = from_col },
            to = { line = line_num, col = to_col },
          }
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
            to = { line = last, col = #vim.fn.getline(last) },
          }
        end,
      },
    }
  end,
}
