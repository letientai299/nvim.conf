local M = {}

local function region(sr, sc, er, ec, linewise)
  if ec == 0 then
    er = er - 1
    ec = #(vim.api.nvim_buf_get_lines(0, er, er + 1, false)[1] or "")
  end
  if er < sr or (er == sr and ec <= sc) then
    return nil
  end
  return {
    from = { line = sr + 1, col = sc + 1 },
    to = { line = er + 1, col = math.max(ec, 1) },
    vis_mode = linewise and "V" or "v",
  }
end

local function node_region(node, linewise)
  local sr, sc, er, ec = node:range()
  return region(sr, sc, er, ec, linewise)
end

local function child_of(node, types)
  for child in node:iter_children() do
    if types[child:type()] then
      return child
    end
  end
end

local function heading(node)
  local content = child_of(node, { inline = true, paragraph = true })
  if not content then
    return nil
  end
  local sr, sc, er, ec = content:range()
  if node:type() == "atx_heading" then
    local text = vim.treesitter.get_node_text(content, 0)
    text = text:gsub("%s+#+%s*$", ""):gsub("%s+$", "")
    ec = sc + #text
  end
  return region(sr, sc, er, ec, false)
end

local function item(node)
  local marker = child_of(node, {
    list_marker_minus = true,
    list_marker_plus = true,
    list_marker_star = true,
    list_marker_dot = true,
    list_marker_parenthesis = true,
  })
  local checkbox = child_of(node, {
    task_list_marker_checked = true,
    task_list_marker_unchecked = true,
  })
  if not marker then
    return nil
  end
  local sr, sc = (checkbox or marker):end_()
  local line = vim.api.nvim_buf_get_lines(0, sr, sr + 1, false)[1] or ""
  sc = sc + #(line:sub(sc + 1):match("^%s*") or "")
  local er, ec = node:end_()
  return region(sr, sc, er, ec, false)
end

local function child_bounds(node, kind)
  local first, last
  for child in node:iter_children() do
    if child:type() == kind then
      first, last = first or child, child
    end
  end
  return first, last
end

local function list(node)
  local first, last = child_bounds(node, "list_item")
  if not first then
    return nil
  end
  local sr, sc = first:start()
  local er, ec = last:end_()
  while er > sr and ec == 0 do
    local line = vim.api.nvim_buf_get_lines(0, er - 1, er, false)[1] or ""
    if line:find("%S") then
      break
    end
    er = er - 1
  end
  return region(sr, sc, er, ec, true)
end

local function table_body(node)
  local first, last = child_bounds(node, "pipe_table_row")
  if not first then
    return nil
  end
  local sr, sc = first:start()
  local er, ec = last:end_()
  return region(sr, sc, er, ec, true)
end

local objects = {
  H = {
    desc = "Section",
    types = { atx_heading = true, setext_heading = true },
  },
  h = {
    desc = "Heading",
    types = { atx_heading = true, setext_heading = true },
    inner = heading,
  },
  u = { desc = "List", types = { list = true }, inner = list },
  i = { desc = "Item", types = { list_item = true }, inner = item },
  t = { desc = "Table", types = { pipe_table = true }, inner = table_body },
  c = {
    desc = "Code block",
    types = { fenced_code_block = true },
    inner = function(node)
      local content = child_of(node, { code_fence_content = true })
      return content and node_region(content, true) or nil
    end,
  },
}

local function heading_level(node)
  for child in node:iter_children() do
    local level = child:type():match("^atx_h(%d)_marker$")
      or child:type():match("^setext_h(%d)_underline$")
    if level then
      return tonumber(level)
    end
  end
  return 7
end

local function sections(nodes, ai_type)
  local result = {}
  for index, node in ipairs(nodes) do
    local sr, sc = node:start()
    if ai_type == "i" then
      sr, sc = node:end_()
    end
    local er, ec = vim.api.nvim_buf_line_count(0), 0
    for next_index = index + 1, #nodes do
      if heading_level(nodes[next_index]) <= heading_level(node) then
        er, ec = nodes[next_index]:start()
        break
      end
    end
    local value = region(sr, sc, er, ec, true)
    if value then
      result[#result + 1] = value
    end
  end
  return result
end

local function find_regions(key, ai_type)
  local ok, parser = pcall(vim.treesitter.get_parser, 0, "markdown")
  if not ok or not parser then
    return {}
  end
  local trees = parser:parse()
  if not trees[1] then
    return {}
  end
  local object, nodes = objects[key], {}
  local function walk(node)
    if object.types[node:type()] then
      nodes[#nodes + 1] = node
    end
    for child in node:iter_children() do
      if child:named() then
        walk(child)
      end
    end
  end
  walk(trees[1]:root())
  if key == "H" then
    return sections(nodes, ai_type)
  end
  local result = {}
  for _, node in ipairs(nodes) do
    local value
    if ai_type == "i" then
      value = object.inner(node)
    else
      value = node_region(node, true)
    end
    if value then
      result[#result + 1] = value
    end
  end
  return result
end

function M.setup(buf)
  local specs = { F = false, o = false, B = false }
  local labels = { F = false, o = false, B = false }
  for key, object in pairs(objects) do
    specs[key] = function(ai_type)
      return find_regions(key, ai_type)
    end
    labels[key] = object.desc
  end
  vim.b[buf].miniai_config =
    vim.tbl_deep_extend("force", vim.b[buf].miniai_config or {}, {
      custom_textobjects = specs,
    })
  vim.b[buf].textobject_labels = labels
end

return M
