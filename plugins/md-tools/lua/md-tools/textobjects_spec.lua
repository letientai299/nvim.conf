-- Run: nvim --headless -u NONE -l plugins/md-tools/lua/md-tools/textobjects_spec.lua
vim.opt.swapfile = false
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:append(vim.fn.getcwd() .. "/plugins/md-tools")
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/site")
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/mini.ai")
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/mini.clue")

local objects = require("md-tools.textobjects")
objects.setup(0)
assert(package.loaded["mini.ai"] == nil)
assert(package.loaded["mini.clue"] == nil)
require("mini.ai").setup(dofile("lua/plugins/mini-ai.lua").opts())
dofile("lua/plugins/mini-clue.lua").config()

local function select_text(text, ai_type, key, row, col, count)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(text, "\n"))
  vim.api.nvim_win_set_cursor(0, { row or 1, col or 0 })
  local value = require("mini.ai").find_textobject(ai_type, key, {
    search_method = "cover",
    n_times = count or 1,
  })
  if not value then
    return nil
  end
  return table.concat(
    vim.api.nvim_buf_get_text(
      0,
      value.from.line - 1,
      value.from.col - 1,
      value.to.line - 1,
      value.to.col,
      {}
    ),
    "\n"
  )
end

local cases = {
  { "# Alpha #", "i", "h", 1, 3, "Alpha" },
  { "# Alpha #", "a", "h", 1, 3, "# Alpha #" },
  { "Title\n=====\nbody", "i", "h", 1, 1, "Title" },
  { "Title\n=====\nbody", "a", "h", 1, 1, "Title\n=====" },
  {
    "# A\nbody\n## B\nchild\n# C\nend",
    "a",
    "H",
    2,
    0,
    "# A\nbody\n## B\nchild",
  },
  { "# A\nbody\n## B\nchild\n# C\nend", "i", "H", 2, 0, "body\n## B\nchild" },
  { "# A\nbody\n## B\nchild\n# C\nend", "a", "H", 4, 0, "## B\nchild" },
  {
    "# A\nbody\n## B\nchild\n# C\nend",
    "a",
    "H",
    4,
    0,
    "# A\nbody\n## B\nchild",
    2,
  },
  { "# A\nbody\n\nTitle\n=====\nend", "a", "H", 2, 0, "# A\nbody\n" },
  { "# A\nbody\n\nTitle\n=====\nend", "a", "H", 6, 0, "Title\n=====\nend" },
  {
    "- [x] first\n  continuation\n  - nested\n- second",
    "i",
    "i",
    1,
    7,
    "first\n  continuation\n  - nested",
  },
  { "1. first\n2. second", "i", "i", 1, 4, "first" },
  { "1) first\n2) second", "i", "i", 1, 4, "first" },
  { "* first\n* second", "a", "i", 1, 4, "* first" },
  { "+ first\n+ second\n\nafter", "i", "u", 1, 4, "+ first\n+ second" },
  { "+ first\n+ second\n\nafter", "a", "u", 1, 4, "+ first\n+ second\n" },
  { "- first\n  - nested\n- second", "a", "u", 2, 5, "- nested" },
  {
    "- first\n  - nested\n- second",
    "a",
    "u",
    2,
    5,
    "- first\n  - nested\n- second",
    2,
  },
  { "| a | b |\n| - | - |\n| c | d |", "i", "t", 3, 3, "| c | d |" },
  {
    "| a | b |\n| - | - |\n| c | d |",
    "a",
    "t",
    3,
    3,
    "| a | b |\n| - | - |\n| c | d |",
  },
  { "```lua\nprint(1)\n```", "i", "c", 2, 2, "print(1)" },
  { "~~~lua\nprint(1)\n~~~", "a", "c", 2, 2, "~~~lua\nprint(1)\n~~~" },
  { "```\n# Fake heading\n```\n# Real\nbody", "a", "H", 5, 0, "# Real\nbody" },
  { "# Empty", "i", "H", 1, 0, nil },
  { "```\n```", "i", "c", 1, 0, nil },
  { "| a | b |\n| - | - |", "i", "t", 1, 0, nil },
  { "  line text", "i", "l", 1, 4, "line text" },
}
for index, case in ipairs(cases) do
  local actual =
    select_text(case[1], case[2], case[3], case[4], case[5], case[7])
  assert(
    actual == case[6],
    index .. ": " .. vim.inspect(actual) .. " ~= " .. vim.inspect(case[6])
  )
end

local function labels()
  local result = {}
  for _, clue in ipairs(require("mini.clue").config.clues) do
    if type(clue) == "function" then
      for _, entry in ipairs(clue()) do
        result[entry.keys] = entry.desc
      end
    end
  end
  return result
end
assert(labels().iH == "Section")
assert(labels().ic == "Code block")
assert(labels().it == "Table")
assert(labels().is == "Sentence")
assert(labels().il == "Line")
assert(labels().iF == nil)
assert(labels().io == nil)
assert(labels().iB == nil)
vim.cmd("enew!")
assert(labels().ic == "Class")
assert(labels().it == "Tag")
assert(labels().iH == nil)
for _, ft in ipairs({ "markdown", "mdx", "quarto" }) do
  vim.bo.filetype = ft
  objects.setup(0)
  objects.setup(0)
  assert(select_text("# Title", "i", "h", 1, 3) == "Title")
end
local get_parser = vim.treesitter.get_parser
-- Exercise missing-parser behavior with a stub.
---@diagnostic disable-next-line: duplicate-set-field
vim.treesitter.get_parser = function()
  error("Missing parser")
end
assert(select_text("# Title", "i", "h", 1, 3) == nil)
vim.treesitter.get_parser = get_parser
print(
  "PASS: "
    .. #cases
    .. " selections, labels, buffer isolation, deferred loading, missing parser"
)
