--- Keyword completion for D2, including fenced blocks in markdown.

local SHAPES = {
  "rectangle",
  "square",
  "page",
  "parallelogram",
  "document",
  "cylinder",
  "queue",
  "package",
  "step",
  "callout",
  "stored_data",
  "person",
  "diamond",
  "oval",
  "circle",
  "hexagon",
  "cloud",
  "text",
  "code",
  "class",
  "sql_table",
  "image",
  "sequence_diagram",
}

local DIRECTIONS = { "up", "down", "left", "right" }

local STYLE = {
  "opacity",
  "stroke",
  "fill",
  "fill-pattern",
  "stroke-width",
  "stroke-dash",
  "border-radius",
  "shadow",
  "3d",
  "multiple",
  "double-border",
  "font",
  "font-size",
  "font-color",
  "animated",
  "bold",
  "italic",
  "underline",
  "filled",
}

local KEYWORDS = {
  "direction",
  "shape",
  "style",
  "label",
  "icon",
  "tooltip",
  "link",
  "near",
  "constraint",
  "width",
  "height",
  "class",
  "classes",
  "vars",
  "layers",
  "scenarios",
  "steps",
  "source-arrowhead",
  "target-arrowhead",
  "text-transform",
  "d2-config",
  "d2-legend",
  "level",
}

local source = {}

function source.new()
  return setmetatable({}, { __index = source })
end

local function cursor_lang()
  local ok, parser = pcall(vim.treesitter.get_parser, 0)
  if not ok or not parser then
    return nil
  end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local range = { row - 1, col, row - 1, col }
  local ok_lang, lang_tree = pcall(parser.language_for_range, parser, range)
  if not ok_lang or not lang_tree then
    return nil
  end
  return lang_tree:lang()
end

function source:enabled()
  return vim.bo.filetype == "d2" or cursor_lang() == "d2"
end

function source:get_trigger_characters()
  return { ".", ":", "-" }
end

local function items(labels, kind)
  local out = {}
  for i, label in ipairs(labels) do
    out[i] = { label = label, kind = kind }
  end
  return out
end

function source:get_completions(context, callback)
  local Kind = require("blink.cmp.types").CompletionItemKind
  local before = context.line:sub(1, context.cursor[2])
  local labels
  if before:match("shape:%s*[%w_%-]*$") then
    labels = SHAPES
  elseif before:match("direction:%s*[%w_%-]*$") then
    labels = DIRECTIONS
  elseif before:match("%.[%w_%-]*$") then
    labels = STYLE
  else
    local seen = {}
    labels = {}
    for _, group in ipairs({ KEYWORDS, SHAPES, DIRECTIONS, STYLE }) do
      for _, label in ipairs(group) do
        if not seen[label] then
          seen[label] = true
          labels[#labels + 1] = label
        end
      end
    end
  end
  callback({
    is_incomplete_forward = false,
    is_incomplete_backward = false,
    items = items(labels, Kind.Keyword),
  })
end

return source
