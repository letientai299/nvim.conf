local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

local function myst()
  return require("lib.notebook").is_myst(vim.api.nvim_get_current_buf())
end

local opts = { condition = myst, show_condition = myst }

return {
  s({ trig = "mtpy", dscr = "MyST Python cell" }, {
    t({ "```{code-cell} ipython3", "" }),
    i(0),
    t({ "", "```" }),
  }, opts),
  s({ trig = "mtraw", dscr = "MyST raw cell" }, {
    t({ "```{raw-cell}", "" }),
    i(0),
    t({ "", "```" }),
  }, opts),
}
