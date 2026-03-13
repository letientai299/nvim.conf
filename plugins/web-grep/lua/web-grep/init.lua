local M = {}

---@class WebGrepEngine
---@field name string
---@field url string|fun(query: string): string
---@field context? boolean|string per-engine context override (string = custom context, true = use global, false = disable)
---@field prompt? boolean force editable prompt before searching

---@class WebGrepConfig
---@field engine_builtin WebGrepEngine[]
---@field context string per-project context keywords (set in .nvim.lua)
---@field default_engine? string skip picker when set

---@type WebGrepConfig
local config = {
  engine_builtin = {
    {
      name = "Google",
      url = "https://google.com/search?q={query}",
      context = true,
    },
    {
      name = "Stack Overflow",
      url = "https://stackoverflow.com/search?q={query}",
      context = true,
    },
    {
      name = "ChatGPT",
      url = "https://chatgpt.com/?q={query}&temporary-chat=true",
      context = true,
      prompt = true,
    },
    {
      name = "DuckDuckGo",
      url = "https://duckduckgo.com/?q={query}",
      context = true,
    },
    {
      name = "GitHub",
      url = "https://github.com/search?q={query}&type=code",
      context = false,
    },
    {
      name = "Microsoft Learn",
      url = "https://learn.microsoft.com/en-us/search/?terms={query}",
      context = true,
    },
    {
      name = "Gemini",
      url = "https://www.google.com/ai?q={query}",
      context = true,
      prompt = true,
    },
    {
      name = "Grok",
      url = "https://grok.com/?q={query}",
      context = true,
      prompt = true,
    },
  },
  context = "",
  default_engine = "Google",
}

---@param str string
---@return string
local function url_encode(str)
  return str
    :gsub("([^%w%-%.%_%~ ])", function(c)
      return ("%%%02X"):format(c:byte())
    end)
    :gsub(" ", "+")
end

---@return string
local function get_visual_selection()
  -- Exit visual mode to populate '< and '> marks
  local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  vim.api.nvim_feedkeys(esc, "nx", false)

  -- getregion handles multibyte chars correctly (nvim 0.10+)
  local lines = vim.fn.getregion(vim.fn.getpos("'<"), vim.fn.getpos("'>"))
  return table.concat(lines, " ")
end

---@param engine WebGrepEngine
---@param query string
---@return string
local function build_url(engine, query)
  local ctx = engine.context
  if ctx ~= false and ctx ~= nil then
    local prefix = type(ctx) == "string" and ctx or config.context
    if prefix ~= "" then
      query = prefix .. " " .. query
    end
  end
  local encoded = url_encode(query)
  if type(engine.url) == "function" then
    return engine.url(encoded)
  end
  -- Function replacement avoids gsub interpreting % in encoded as capture refs
  return (engine.url:gsub("{query}", function()
    return encoded
  end))
end

---@param name string
---@return WebGrepEngine?
local function find_engine(name)
  for _, e in ipairs(config.engine_builtin) do
    if e.name == name then
      return e
    end
  end
end

---@param engine WebGrepEngine
---@param query string
---@param prompted boolean whether vim.ui.input was already shown
local function open_engine(engine, query, prompted)
  if engine.prompt and not prompted then
    vim.ui.input({ prompt = "Search: ", default = query }, function(input)
      if input and input ~= "" then
        vim.ui.open(build_url(engine, input))
      end
    end)
    return
  end
  vim.ui.open(build_url(engine, query))
end

---@param query string
---@param engine_name? string
---@param prompted boolean
local function resolve_engine_and_search(query, engine_name, prompted)
  if engine_name then
    local engine = find_engine(engine_name)
    if not engine then
      vim.notify(
        "web-grep: unknown engine " .. engine_name,
        vim.log.levels.ERROR
      )
      return
    end
    open_engine(engine, query, prompted)
    return
  end

  vim.ui.select(config.engine_builtin, {
    prompt = "Search engine > ",
    format_item = function(e)
      return e.name
    end,
  }, function(engine)
    if engine then
      open_engine(engine, query, prompted)
    end
  end)
end

---@param opts? { engine?: string, prompt?: boolean, visual?: boolean }
function M.search(opts)
  opts = opts or {}
  local query = opts.visual and get_visual_selection()
    or vim.fn.expand("<cword>")

  if opts.prompt then
    vim.ui.input({ prompt = "Search: ", default = query }, function(input)
      if input and input ~= "" then
        resolve_engine_and_search(input, opts.engine, true)
      end
    end)
    return
  end

  if query == "" then
    vim.notify("web-grep: empty query", vim.log.levels.WARN)
    return
  end

  resolve_engine_and_search(query, opts.engine, false)
end

---@class WebGrepSetupOpts
---@field engines? table<string, table> name-keyed overrides/additions for engines
---@field context? string per-project context keywords
---@field default_engine? string skip picker when set

---@param opts? WebGrepSetupOpts
function M.setup(opts)
  opts = opts or {}
  local engine_overrides = opts.engines
  opts.engines = nil

  -- Apply non-engine options
  if opts.context ~= nil then
    config.context = opts.context
  end
  if opts.default_engine ~= nil then
    config.default_engine = opts.default_engine
  end

  -- Apply engine overrides/additions
  if engine_overrides then
    for name, patch in pairs(engine_overrides) do
      local found = false
      for _, builtin in ipairs(config.engine_builtin) do
        if builtin.name == name then
          -- Patch existing builtin
          for k, v in pairs(patch) do
            builtin[k] = v
          end
          found = true
          break
        end
      end
      if not found then
        -- Guard against duplicate appends on repeated setup() calls
        if find_engine(name) then
          -- Already added in a previous setup() call; patch instead
          local existing = find_engine(name)
          for k, v in pairs(patch) do
            existing[k] = v
          end
        else
          if not patch.url then
            vim.notify(
              "web-grep: new engine " .. name .. " is missing url",
              vim.log.levels.WARN
            )
          end
          -- Shallow-copy to avoid mutating caller's table
          local engine = { name = name }
          for k, v in pairs(patch) do
            engine[k] = v
          end
          table.insert(config.engine_builtin, engine)
        end
      end
    end
  end

  vim.api.nvim_create_user_command("WebGrep", function()
    M.search()
  end, { desc = "Search cword in browser" })

  vim.api.nvim_create_user_command("WebGrepPrompt", function()
    M.search({ prompt = true })
  end, { desc = "Search with editable prompt in browser" })
end

---@return string
function M.get_default_engine()
  return config.default_engine
end

return M
