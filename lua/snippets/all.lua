local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node

local function comment_prefix()
  local cs = vim.bo.commentstring
  if cs and cs:match("%%s") then
    return (cs:gsub("%%s", ""):gsub("%s+$", ""))
  end
  return "//"
end

return {
  s("td", { f(function() return comment_prefix() .. " TODO (tai): " end), i(0) }),
  s("nt", { f(function() return comment_prefix() .. " NOTE (tai): " end), i(0) }),
  s("fm", { f(function() return comment_prefix() .. " FIXME (tai): " end), i(0) }),
}
