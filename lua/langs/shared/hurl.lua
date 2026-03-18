local nav = require("lib.nav_keys")

local M = {}

-- Pattern matching HTTP method keywords at column 1 (start of hurl entry).
local entry_pat =
  [[\v^(GET|POST|PUT|DELETE|PATCH|OPTIONS|HEAD|CONNECT|TRACE)\s]]

function M.setup(bufnr)
  require("langs.shared.entry").setup("hurl", bufnr, {
    tools = { { bin = "hurlfmt", mise = "hurl" } },
    formatters = { "hurlfmt" },
    linters = { "hurlfmt" },
    each = function(buf)
      vim.keymap.set("n", nav.next, function()
        vim.cmd("normal! m'")
        vim.fn.search(entry_pat, "W")
      end, { buffer = buf, desc = "Next hurl entry" })
      vim.keymap.set("n", nav.prev, function()
        vim.cmd("normal! m'")
        vim.fn.search(entry_pat, "bW")
      end, { buffer = buf, desc = "Prev hurl entry" })
    end,
    once = function()
      -- hurlfmt parse errors: error: <msg>\n  --> <file>:<line>:<col>
      require("lint").linters.hurlfmt = {
        cmd = "hurlfmt",
        stdin = true,
        stream = "stderr",
        parser = function(output)
          local diags = {}
          for msg, line, col in
            output:gmatch("error: ([^\n]+)\n%s*%-%-> [^:]+:(%d+):(%d+)")
          do
            diags[#diags + 1] = {
              lnum = tonumber(line) - 1,
              col = tonumber(col) - 1,
              severity = vim.diagnostic.severity.ERROR,
              source = "hurlfmt",
              message = msg,
            }
          end
          return diags
        end,
      }
    end,
  })
end

return M
