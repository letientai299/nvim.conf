local M = {}

---@class WebGrepEngine
---@field name string
---@field url string|fun(query: string): string
---@field context? boolean prepend config.context to query when true

---@class WebGrepConfig
---@field engines WebGrepEngine[]
---@field context string per-project context keywords (set in .nvim.lua)
---@field default_engine? string skip picker when set

---@type WebGrepConfig
local config = {
  engines = {
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
      name = "Google Maps",
      url = "https://google.com/maps/search/{query}",
      context = false,
    },
  },
  context = "",
  default_engine = nil,
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
  if engine.context and config.context ~= "" then
    query = config.context .. " " .. query
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
  for _, e in ipairs(config.engines) do
    if e.name == name then
      return e
    end
  end
end

---@param query string
---@param engine_name? string
local function resolve_engine_and_search(query, engine_name)
  if engine_name then
    local engine = find_engine(engine_name)
    if not engine then
      vim.notify(
        "web-grep: unknown engine " .. engine_name,
        vim.log.levels.ERROR
      )
      return
    end
    vim.ui.open(build_url(engine, query))
    return
  end

  if config.default_engine then
    local engine = find_engine(config.default_engine)
    if not engine then
      vim.notify(
        "web-grep: unknown default_engine " .. config.default_engine,
        vim.log.levels.WARN
      )
    else
      vim.ui.open(build_url(engine, query))
      return
    end
  end

  vim.ui.select(config.engines, {
    prompt = "Search engine",
    format_item = function(e)
      return e.name
    end,
  }, function(engine)
    if engine then
      vim.ui.open(build_url(engine, query))
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
        resolve_engine_and_search(input, opts.engine)
      end
    end)
    return
  end

  if query == "" then
    vim.notify("web-grep: empty query", vim.log.levels.WARN)
    return
  end

  resolve_engine_and_search(query, opts.engine)
end

---@param opts? WebGrepConfig
function M.setup(opts)
  config = vim.tbl_extend("force", config, opts or {})

  vim.api.nvim_create_user_command("WebGrep", function()
    M.search()
  end, { desc = "Search cword in browser" })

  vim.api.nvim_create_user_command("WebGrepPrompt", function()
    M.search({ prompt = true })
  end, { desc = "Search with editable prompt in browser" })
end

return M
