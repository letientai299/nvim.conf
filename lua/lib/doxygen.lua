-- Render Doxygen doc comments in LSP hover/signature docs.
--
-- clangd extracts a symbol's doc comment and ships it as markdown, but passes
-- Doxygen commands through verbatim: `\brief`, `\return`, `\note`, `\sa`,
-- `\param`, and scope auto-links like `::cudaSuccess`. Markdown doesn't know
-- Doxygen, so nvim renders the raw commands. clangd escapes the backslash for
-- markdown, so a command arrives as `\\brief` (two backslashes) -- patterns
-- below match one-or-more. Doxygen command reference:
-- https://www.doxygen.nl/manual/commands.html
--
-- `install()` wraps the single conversion chokepoint nvim uses for hover and
-- signature help; it is gated to C-family filetypes by the caller so regex-ish
-- docs in other languages (`\d`, `\n`) are never touched.

local M = {}

-- Line-leading commands that open a labeled section. Value is the markdown
-- label; empty string keeps the following text but drops the command.
local SECTION = {
  brief = "",
  short = "",
  details = "",
  ["return"] = "**Returns:** ",
  returns = "**Returns:** ",
  retval = "**Returns:** ",
  note = "**Note:** ",
  remark = "**Note:** ",
  remarks = "**Note:** ",
  warning = "**Warning:** ",
  attention = "**Warning:** ",
  sa = "**See also:** ",
  see = "**See also:** ",
  ["throws"] = "**Throws:** ",
  ["throw"] = "**Throws:** ",
}

--- Strip a Doxygen scope prefix and wrap the symbol in inline code.
--- `::cudaSuccess` -> `` `cudaSuccess` ``. Called only on leading `::` links so
--- qualified names in normal text (`std::vector`) are left alone.
---@param sym string
---@return string
local function code_link(sym)
  return "`" .. (sym:gsub("^:+", "")) .. "`"
end

--- Apply the Doxygen->markdown substitutions to a single (non-fenced) line.
---@param line string
---@return string
local function transform(line)
  -- \param[in] name / \tparam name  ->  labeled, backticked name. Trailing
  -- %s* eats the gap before the description so the label spacing stays single.
  line = line:gsub("\\+tparam%s*%[?[%w,%s]*%]?%s*([%w_]+)%s*", "**Tparam** `%1` — ")
  line = line:gsub("\\+param%s*%[?[%w,%s]*%]?%s*([%w_]+)%s*", "**Param** `%1` — ")

  -- Inline face commands taking one word: \p \c \ref -> code, \b -> bold,
  -- \a \e \em -> italic. Ordered after \param so \p doesn't shadow it.
  line = line:gsub("\\+(ref)%s+([%w_:]+)", function(_, w)
    return code_link(w)
  end)
  line = line:gsub("\\+([pcbaem]+)%s+([%w_:%(%)]+)", function(cmd, word)
    if cmd == "p" or cmd == "c" then
      return code_link(word)
    elseif cmd == "b" then
      return "**" .. (word:gsub("^:+", "")) .. "**"
    elseif cmd == "a" or cmd == "e" or cmd == "em" then
      return "*" .. (word:gsub("^:+", "")) .. "*"
    end
    return word
  end)

  -- Leading section command: relabel if known, else drop the whole command
  -- word (CUDA aliases like \note_init_rt aren't standard and can't expand).
  -- Trailing %s* eats the gap after the command so the label spacing is single.
  line = line:gsub("^(%s*)\\+([%a][%w_]*)%s*", function(indent, cmd)
    return indent .. (SECTION[cmd] or "")
  end)

  -- Any leftover command tokens anywhere on the line: drop them.
  line = line:gsub("\\+[%a][%w_]*", "")

  -- Scope auto-links. Leading `::sym` (line start or after a non-word char) so
  -- `foo::bar` in prose/code is preserved.
  line = line:gsub("^::([%w_]+)", code_link)
  line = line:gsub("([^%w_:])::([%w_]+)", function(pre, sym)
    return pre .. code_link(sym)
  end)

  return line
end

--- Convert Doxygen commands in a markdown string to plain markdown. No-op fast
--- path when the text has no Doxygen markers. Code fences pass through untouched
--- so signatures aren't rewritten.
---@param text string
---@return string
function M.to_markdown(text)
  if type(text) ~= "string" then
    return text
  end
  if not text:find("\\", 1, true) and not text:find("::", 1, true) then
    return text
  end

  local out, in_fence = {}, false
  for _, line in ipairs(vim.split(text, "\n", { plain = true })) do
    if line:match("^%s*```") then
      in_fence = not in_fence
      out[#out + 1] = line
    elseif in_fence then
      out[#out + 1] = line
    else
      local had_cmd = line:find("\\", 1, true) ~= nil
      local rendered = transform(line)
      -- Drop lines that were nothing but a stripped alias (e.g. \notefnerr).
      if not (had_cmd and rendered:match("^%s*$")) then
        out[#out + 1] = rendered
      end
    end
  end
  return table.concat(out, "\n")
end

--- Clean the value(s) of an LSP hover/signature input without mutating the
--- original (results may be cached). Handles a bare string, MarkupContent
--- (`{ kind, value }`), MarkedString (`{ language, value }` -- skipped when a
--- language is set, i.e. a code block), and arrays thereof.
---@param input any
---@return any
function M.clean_input(input)
  if type(input) == "string" then
    return M.to_markdown(input)
  end
  if type(input) ~= "table" then
    return input
  end
  if vim.islist(input) then
    local copy = {}
    for i, v in ipairs(input) do
      copy[i] = M.clean_input(v)
    end
    return copy
  end
  -- MarkupContent, or MarkedString without a language (plain text/markdown).
  if type(input.value) == "string" and input.language == nil then
    local copy = vim.deepcopy(input)
    copy.value = M.to_markdown(input.value)
    return copy
  end
  return input
end

local C_FAMILY = { c = true, cpp = true, cuda = true, objc = true, objcpp = true }

--- Wrap `vim.lsp.util.convert_input_to_markdown_lines` (used by hover and
--- signature help) so Doxygen docs render as markdown. Idempotent. Gated to
--- C-family buffers -- the filetype of the buffer K/signature-help fires in --
--- so other languages' docs are untouched.
function M.install()
  local util = vim.lsp.util
  if util._doxygen_wrapped then
    return
  end
  util._doxygen_wrapped = true

  local orig = util.convert_input_to_markdown_lines
  util.convert_input_to_markdown_lines = function(input, ...)
    if C_FAMILY[vim.bo.filetype] then
      input = M.clean_input(input)
    end
    return orig(input, ...)
  end
end

return M
