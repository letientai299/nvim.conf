--- hover.nvim provider: Vim help tags
--- Shows :help content for the word under cursor in vim/help filetypes.

local help_fts = { vim = true, help = true, lua = true }

return {
  name = "Vim Help",
  priority = 900,

  ---@param bufnr integer
  enabled = function(bufnr)
    return help_fts[vim.bo[bufnr].filetype] ~= nil
  end,

  ---@param params Hover.Provider.Params
  ---@param done fun(result?: false|Hover.Provider.Result)
  execute = function(params, done)
    local word = vim.fn.expand("<cword>")
    if word == "" then
      return done(false)
    end

    -- Try to find the help tag
    local ok, tag_match = pcall(vim.fn.taglist, "^" .. vim.fn.escape(word, "\\") .. "$", "")
    if not ok or #tag_match == 0 then
      return done(false)
    end

    -- Find the help file and extract content around the tag
    for _, tag in ipairs(tag_match) do
      local filename = tag.filename or ""
      if filename:match("doc/") and filename:match("%.txt$") then
        local lines = vim.fn.readfile(filename)
        if #lines == 0 then
          goto continue
        end

        -- Find the tag line
        local pattern = vim.fn.escape(word, "\\")
        local start_line = nil
        for i, line in ipairs(lines) do
          if line:find(pattern, 1, true) and line:find("%*" .. vim.pesc(word) .. "%*") then
            start_line = i
            break
          end
        end

        if not start_line then
          -- Fallback: use the tag's cmd pattern
          start_line = 1
        end

        -- Extract a reasonable excerpt (up to next section or 30 lines)
        local end_line = math.min(start_line + 30, #lines)
        for i = start_line + 1, end_line do
          -- Stop at separator lines or next tag definition at line start
          if lines[i] and (lines[i]:match("^===") or lines[i]:match("^%-%-%-")) then
            end_line = i - 1
            break
          end
        end

        local excerpt = {}
        for i = start_line, end_line do
          for _, part in ipairs(vim.split(lines[i] or "", "\n", { plain = true })) do
            excerpt[#excerpt + 1] = part
          end
        end
        return done({ lines = excerpt, filetype = "help" })
      end
      ::continue::
    end

    done(false)
  end,
}
