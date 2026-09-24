local M = {}

function M.setup()
  vim.filetype.add({
    filename = { ["CITATION.cff"] = "yaml" },
    pattern = {
      [".*%.pdb"] = function(_, buf)
        for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, 80, false)) do
          if
            (line:match("^ATOM  ") or line:match("^HETATM"))
            and tonumber(line:sub(7, 11))
            and tonumber(line:sub(31, 38))
            and tonumber(line:sub(39, 46))
            and tonumber(line:sub(47, 54))
          then
            return "pdb"
          end
        end
      end,
      [".*%.pt"] = function(_, buf)
        local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
        if line:sub(1, 4) == "PK\003\004" or line:match("^\128[\002-\005]") then
          return "binary",
            function(buffer)
              vim.bo[buffer].buftype = "nowrite"
              vim.bo[buffer].readonly = true
              vim.bo[buffer].modifiable = false
              vim.bo[buffer].swapfile = false
            end
        end
      end,
    },
  })
end

return M
