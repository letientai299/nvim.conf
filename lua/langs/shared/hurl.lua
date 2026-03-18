local M = {}

function M.setup(bufnr)
  require("langs.shared.entry").setup("hurl", bufnr, {
    tools = { { bin = "hurlfmt", mise = "hurl" } },
    formatters = { "hurlfmt" },
    linters = { "hurlfmt" },
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
