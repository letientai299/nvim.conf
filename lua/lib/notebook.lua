local M = {}

local api = vim.api
local cell_query
local query_registered = false

local function code_range(node, source)
  local sr, sc, er, ec = node:range()
  local lines = vim.split(vim.treesitter.get_node_text(node, source), "\n")
  local skipped = 0
  if lines[1]:match("^%s*%-%-%-%s*$") then
    for row = 2, #lines do
      if lines[row]:match("^%s*%-%-%-%s*$") then
        skipped = row
        break
      end
    end
  else
    for row, line in ipairs(lines) do
      if not line:match("^%s*:[%w_%-]+:") then
        break
      end
      skipped = row
    end
  end
  if skipped > 0 then
    while lines[skipped + 1] and lines[skipped + 1]:match("^%s*$") do
      skipped = skipped + 1
    end
    sr = math.min(sr + skipped, er)
    sc = sr == er and ec or 0
  end
  return { sr, sc, er, ec }
end

function M.register_query()
  if query_registered then
    return
  end
  query_registered = true
  vim.treesitter.query.add_directive(
    "myst-code!",
    function(match, _, source, predicate, metadata)
      local capture = predicate[2]
      local node = match[capture][1]
      metadata[capture] = metadata[capture] or {}
      metadata[capture].range = code_range(node, source)
    end
  )
end

local function python_cell(info)
  return info:match("^{code%-cell}%s+i?python3?%s*$") ~= nil
end

function M.is_myst(buf)
  if not api.nvim_buf_is_valid(buf) then
    return false
  end
  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  local frontmatter = lines[1] == "---"
  for row, line in ipairs(lines) do
    if row > 1 and line == "---" then
      frontmatter = false
    end
    if frontmatter and line:match("^%s*format_name:%s*myst%s*$") then
      return true
    end
    local info = line:match("^%s*```+(.+)$") or line:match("^%s*~~~+(.+)$")
    if info and python_cell(info) then
      return true
    end
  end
  return false
end

local function is_notebook(buf)
  if not api.nvim_buf_is_valid(buf) then
    return false
  end
  if M.is_myst(buf) then
    return true
  end
  for _, line in ipairs(api.nvim_buf_get_lines(buf, 0, -1, false)) do
    if
      line:match("^marimo%-version:%s*")
      or line:match("^```.*{[^}]*%.?marimo[^}]*}")
    then
      return true
    end
  end
  return false
end

local function cells(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
  if not ok or not parser then
    return {}
  end
  cell_query = cell_query
    or vim.treesitter.query.parse(
      "markdown",
      "(fenced_code_block (info_string) @info) @cell"
    )
  local result = {}
  for _, tree in ipairs(parser:parse()) do
    for _, match in cell_query:iter_matches(tree:root(), buf) do
      local info, cell = match[1][1], match[2][1]
      if python_cell(vim.treesitter.get_node_text(info, buf)) then
        local sr, _, er, ec = cell:range()
        local first = sr + 2
        for child in cell:iter_children() do
          if child:type() == "code_fence_content" then
            first = code_range(child, buf)[1] + 1
            break
          end
        end
        result[#result + 1] = {
          metadata_first = sr + 2,
          first = first,
          last = ec == 0 and er - 1 or er,
        }
      end
    end
  end
  return result
end

function M.indent()
  local row = vim.v.lnum
  for _, cell in ipairs(cells(0)) do
    if row >= cell.metadata_first and row < cell.first then
      return vim.fn.indent(row)
    end
    if row >= cell.first and row <= cell.last then
      if vim.fn.prevnonblank(row - 1) < cell.first then
        return 0
      end
      return vim.fn["python#GetIndent"](row)
    end
    if row == cell.last + 1 then
      return 0
    end
  end
  return -1
end

function M.setup_editing(buf)
  if not M.is_myst(buf) then
    return
  end
  vim.bo[buf].indentexpr = "v:lua.require'lib.notebook'.indent()"
  vim.opt_local.indentkeys:append({ "<:>", "=elif", "=except" })
end

function M.setup(buf)
  if not is_notebook(buf) then
    return
  end
  M.register_query()
  local ondemand = require("lib.lazy_ondemand")
  local function activate()
    if not is_notebook(buf) or not package.loaded["otter"] then
      return
    end
    local raft = require("otter.keeper").rafts[buf]
    if raft and raft.buffers.python then
      return
    end
    if not pcall(vim.treesitter.language.add, "python") then
      return
    end
    local ok, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
    if not ok or not parser then
      return
    end
    api.nvim_buf_call(buf, function()
      require("otter").activate({ "python" }, true, true)
    end)
  end
  local group = api.nvim_create_augroup("notebook:" .. buf, { clear = true })
  -- Parsers may already be installing.
  api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
    group = group,
    buffer = buf,
    callback = activate,
  })
  ondemand.on_load("otter.nvim", function()
    require("tree-sitter-manager.installer").install(
      { "markdown", "python" },
      function()
        vim.schedule(activate)
      end
    )
    vim.schedule(activate)
  end)
  require("lazy").load({ plugins = { "otter.nvim" } })
end

return M
