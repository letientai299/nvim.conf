vim.opt.rtp:prepend(vim.fn.getcwd())
require("lib.notebook").register_query()

local query = vim.treesitter.query.parse(
  "markdown",
  [[
    ((fenced_code_block
      (code_fence_content) @content)
      (#myst-code! @content))
  ]]
)
for _, case in ipairs({
  { "x = 1", "x = 1\n" },
  {
    ":jupyter: {source_hidden: true, outputs_hidden: false}\n\nx = 1",
    "x = 1\n",
  },
  {
    "---\njupyter:\n  source_hidden: true\n---\nx = 1",
    "x = 1\n",
  },
  {
    ":tags: [hide-input]\n:jupyter: {source_hidden: true}\n\nx = 1",
    "x = 1\n",
  },
  { ":jupyter: {source_hidden: true}\n", "" },
}) do
  local source = "```{code-cell} ipython3\n" .. case[1] .. "\n```\n"
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(source, "\n"))
  for _, input in ipairs({ source, buf }) do
    local parser = type(input) == "string"
        and vim.treesitter.get_string_parser(input, "markdown")
      or vim.treesitter.get_parser(input, "markdown")
    local found = false
    for id, node, metadata in
      query:iter_captures(parser:parse()[1]:root(), input)
    do
      local code
      if type(input) == "string" then
        local range = vim.treesitter.get_range(node, input, metadata[id])
        code = input:sub(range[3] + 1, range[6])
      else
        code = vim.treesitter.get_node_text(node, input, {
          metadata = metadata[id],
        })
      end
      assert(
        code == case[2],
        "Unexpected Python range: "
          .. vim.inspect({ code, case[2], metadata[id] })
      )
      found = true
    end
    assert(found, "MyST cell content missing")
  end
  vim.api.nvim_buf_delete(buf, { force = true })
end
local yaml = {
  "```{code-cell} ipython3",
  "---",
  "jupyter:",
  "  source_hidden: true",
  "  outputs_hidden: false",
  "---",
  "x = 1",
  "```",
}
vim.api.nvim_buf_set_lines(0, 0, -1, false, yaml)
vim.bo.shiftwidth = 4
vim.bo.autoindent = true
require("lib.notebook").setup_editing(vim.api.nvim_get_current_buf())
vim.cmd("normal! gg=G")
assert(
  vim.deep_equal(yaml, vim.api.nvim_buf_get_lines(0, 0, -1, false)),
  "Python indentation changed MyST metadata"
)
print("MyST metadata exclusion checks passed")
