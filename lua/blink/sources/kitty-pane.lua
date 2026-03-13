--- blink.cmp source: completions from other Kitty terminal panes
--- Extracts words, file paths, and URLs from visible pane text.

local MAX_WINDOWS = 8
local NS_PER_SEC = 1e9

--- @module 'blink.cmp'
--- @class blink.cmp.Source
local source = {}

function source.new(opts)
  local self = setmetatable({}, { __index = source })
  self.cache = nil
  self.cache_ttl = ((opts and opts.cache_ttl) or 5) * NS_PER_SEC
  -- Window IDs change rarely — cache separately with longer TTL
  self.wid_cache = nil
  self.wid_cache_ttl = ((opts and opts.wid_cache_ttl) or 30) * NS_PER_SEC
  -- Cache env vars once — they don't change during a session
  self.listen_on = vim.env.KITTY_LISTEN_ON
  self.self_wid = tonumber(vim.env.KITTY_WINDOW_ID)
  self.kitty_available = vim.env.KITTY_PID ~= nil and self.listen_on ~= nil
  return self
end

function source:enabled()
  return self.kitty_available
end

--- Shallow-copy a list of items (sufficient since values are primitives).
---@param items lsp.CompletionItem[]
---@return lsp.CompletionItem[]
local function copy_items(items)
  local out = {}
  for i = 1, #items do
    local it = items[i]
    out[i] = { label = it.label, kind = it.kind, score_offset = it.score_offset }
  end
  return out
end

--- Classify and extract a token from text starting at pos.
--- Returns (label, kind_key, offset, end_pos) or nil.
---@param text string
---@param pos number
---@param Kind table
---@return string?, number?, number?, number?
local function extract_token(text, pos, Kind)
  -- URL: starts with http:// or https://
  local url, url_end = text:match("^(https?://[%w%-%.%_%~%:%/%?#%[%]@!%$&'%(%)%*%+,;%%=]+)()", pos)
  if url then return url, Kind.Reference, 10, url_end end

  -- File path: starts with ~ / . and contains at least one /
  local path, path_end = text:match("^([~/%.][%w%-%.%_%~/]+/[%w%-%.%_%~/]*[%w%-%.%_])()", pos)
  if path then return path, Kind.File, 8, path_end end

  -- Word: 4+ alphanumeric/hyphen/underscore chars
  local word, word_end = text:match("^([%w][%w%-_]+[%w])()", pos)
  if word and #word >= 4 then return word, Kind.Text, 0, word_end end

  return nil
end

---@param text string
---@return lsp.CompletionItem[]
local function parse_items(text)
  local Kind = require("blink.cmp.types").CompletionItemKind
  local seen = {}
  local items = {}
  local len = #text
  local pos = 1

  while pos <= len do
    local label, kind, offset, next_pos = extract_token(text, pos, Kind)
    if label then
      if not seen[label] then
        seen[label] = true
        items[#items + 1] = { label = label, kind = kind, score_offset = offset }
      end
      pos = next_pos
    else
      -- Advance past current char to find next potential token start
      pos = pos + 1
    end
  end

  return items
end

--- Parse `kitty @ ls` JSON into a list of non-self window IDs (capped).
---@param json_str string
---@param self_wid number?
---@return number[]
local function parse_window_ids(json_str, self_wid)
  local ok, data = pcall(vim.json.decode, json_str)
  if not ok or type(data) ~= "table" then return {} end

  local ids = {}
  for _, os_win in ipairs(data) do
    for _, tab in ipairs(os_win.tabs or {}) do
      for _, w in ipairs(tab.windows or {}) do
        if w.id ~= self_wid then ids[#ids + 1] = w.id end
      end
    end
  end

  -- Keep the last MAX_WINDOWS (highest IDs = most recently created)
  if #ids > MAX_WINDOWS then
    local capped = {}
    for i = #ids - MAX_WINDOWS + 1, #ids do
      capped[#capped + 1] = ids[i]
    end
    return capped
  end
  return ids
end

--- Fetch screen text from a list of kitty window IDs in parallel.
---@param listen_on string
---@param win_ids number[]
---@param on_done fun(text: string)
---@return fun() cancel
local function fetch_pane_texts(listen_on, win_ids, on_done)
  local cancelled = false
  local jobs = {}

  local function cancel()
    cancelled = true
    for _, j in ipairs(jobs) do
      j:kill()
    end
  end

  if #win_ids == 0 then
    vim.schedule(function() on_done("") end)
    return cancel
  end

  local texts = {}
  local remaining = #win_ids
  for _, wid in ipairs(win_ids) do
    local j = vim.system(
      { "kitty", "@", "--to", listen_on, "get-text", "--match", "id:" .. wid, "--extent", "screen" },
      { text = true },
      function(result)
        if not cancelled and result.code == 0 and result.stdout then
          texts[#texts + 1] = result.stdout
        end
        remaining = remaining - 1
        if remaining == 0 then
          vim.schedule(function()
            if not cancelled then on_done(table.concat(texts, "\n")) end
          end)
        end
      end
    )
    jobs[#jobs + 1] = j
  end

  return cancel
end

function source:get_completions(_, callback)
  local now = vim.uv.hrtime()
  if self.cache and (now - self.cache.ts) < self.cache_ttl then
    callback({
      items = copy_items(self.cache.items),
      is_incomplete_forward = false,
      is_incomplete_backward = false,
    })
    return
  end

  local respond = function(text)
    local items = {}
    if #text > 0 then
      items = parse_items(text)
    end
    if #items > 0 then
      self.cache = { items = items, ts = vim.uv.hrtime() }
    end
    callback({
      items = copy_items(items),
      is_incomplete_forward = false,
      is_incomplete_backward = false,
    })
  end

  -- Reuse cached window IDs when fresh (windows don't appear/disappear often)
  if self.wid_cache and (now - self.wid_cache.ts) < self.wid_cache_ttl then
    return fetch_pane_texts(self.listen_on, self.wid_cache.ids, respond)
  end

  -- Need fresh window list from kitty @ ls
  local cancelled = false
  local inner_cancel = nil

  local ls_job = vim.system(
    { "kitty", "@", "--to", self.listen_on, "ls" },
    { text = true },
    function(ls_result)
      if cancelled or ls_result.code ~= 0 then
        return vim.schedule(function() respond("") end)
      end
      local ids = parse_window_ids(ls_result.stdout, self.self_wid)
      self.wid_cache = { ids = ids, ts = vim.uv.hrtime() }
      vim.schedule(function()
        if not cancelled then
          inner_cancel = fetch_pane_texts(self.listen_on, ids, respond)
        end
      end)
    end
  )

  return function()
    cancelled = true
    ls_job:kill()
    if inner_cancel then inner_cancel() end
  end
end

return source
