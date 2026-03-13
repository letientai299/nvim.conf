--- blink.cmp source: completions from other Kitty terminal panes.
---
--- Fetches words, file paths, and URLs from recently focused windows
--- in the same tab as neovim, using kitty's `recent:N` match selector.
--- Completions are cached for a configurable TTL (default 5s).
---
--- Requires `allow_remote_control` and `listen_on` in kitty.conf.
--- The source auto-disables when KITTY_PID or KITTY_LISTEN_ON is unset.

--- Max panes to fetch per cache miss. Kitty's `recent:N` is scoped to the
--- active tab, so 4 covers most split layouts without excessive subprocesses.
local MAX_WINDOWS = 4
local NS_PER_SEC = 1e9

--- @module 'blink.cmp'
--- @class blink.cmp.Source
local source = {}

--- @param opts? { cache_ttl?: number }
function source.new(opts)
  local self = setmetatable({}, { __index = source })
  self.cache = nil
  self.cache_ttl = ((opts and opts.cache_ttl) or 5) * NS_PER_SEC
  -- Cached once — env vars don't change during a session.
  self.listen_on = vim.env.KITTY_LISTEN_ON
  self.kitty_available = vim.env.KITTY_PID ~= nil and self.listen_on ~= nil
  return self
end

function source:enabled()
  return self.kitty_available
end

--- Shallow-copy items. blink.cmp mutates items in-place (adds source_id,
--- score_offset, etc.), so the cache must not be handed out directly.
--- A shallow per-item copy suffices since all values are primitives.
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

--- Try to match a URL, file path, or word at the given position.
--- Patterns are tried in priority order: URL > path > word.
--- Returns (label, kind, score_offset, end_pos) or nil.
---@param text string
---@param pos number
---@param Kind table  CompletionItemKind enum from blink.cmp
---@return string?, number?, number?, number?
local function extract_token(text, pos, Kind)
  local url, url_end = text:match("^(https?://[%w%-%.%_%~%:%/%?#%[%]@!%$&'%(%)%*%+,;%%=]+)()", pos)
  if url then return url, Kind.Reference, 10, url_end end

  local path, path_end = text:match("^([~/%.][%w%-%.%_%~/]+/[%w%-%.%_%~/]*[%w%.%_])()", pos)
  if path then
    path = path:gsub("%.+$", "") -- strip trailing sentence punctuation
    if #path >= 4 then return path, Kind.File, 8, path_end end
  end

  local word, word_end = text:match("^([%w][%w%-_]+[%w])()", pos)
  if word and #word >= 4 then return word, Kind.Text, 0, word_end end

  return nil
end

--- Single-pass tokenizer: scan text left-to-right, extracting the longest
--- token at each position. Deduplicates via a hash set. After extraction,
--- removes truncated URLs/paths caused by terminal line wraps (e.g., a
--- long URL split across two lines produces both a truncated and full match).
---@param text string  concatenated screen text from kitty panes
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
      pos = pos + 1
    end
  end

  -- Deduplicate truncated URLs/paths: sort by (kind, label) so prefixes are
  -- adjacent, then drop any item whose label is a prefix of the next item's.
  local linkable = {}
  local rest = {}
  for _, it in ipairs(items) do
    if it.kind == Kind.Reference or it.kind == Kind.File then
      linkable[#linkable + 1] = it
    else
      rest[#rest + 1] = it
    end
  end
  table.sort(linkable, function(a, b)
    if a.kind ~= b.kind then return a.kind < b.kind end
    return a.label < b.label
  end)
  local out = {}
  for i, it in ipairs(linkable) do
    local nxt = linkable[i + 1]
    local is_prefix = nxt and nxt.kind == it.kind and nxt.label:sub(1, #it.label) == it.label
    if not is_prefix then out[#out + 1] = it end
  end
  vim.list_extend(out, rest)

  return out
end

--- Fetch screen text from the N most recently focused windows in the active
--- tab, in parallel. Skips recent:0 (neovim's own window). Calls on_done
--- with concatenated text once all subprocesses finish.
---@param listen_on string  kitty IPC socket path (KITTY_LISTEN_ON)
---@param on_done fun(text: string)
---@return fun() cancel  kills all in-flight subprocesses
local function fetch_recent_panes(listen_on, on_done)
  local cancelled = false
  local jobs = {}
  local texts = {}
  local remaining = MAX_WINDOWS

  local function cancel()
    cancelled = true
    for _, j in ipairs(jobs) do
      j:kill()
    end
  end

  local function on_exit(result)
    if not cancelled and result.code == 0 and result.stdout then
      texts[#texts + 1] = result.stdout
    end
    remaining = remaining - 1
    if remaining > 0 or cancelled then return end
    vim.schedule(function() on_done(table.concat(texts, "\n")) end)
  end

  for i = 1, MAX_WINDOWS do
    local j = vim.system(
      { "kitty", "@", "--to", listen_on, "get-text", "--match", "recent:" .. i, "--extent", "screen" },
      { text = true },
      on_exit
    )
    jobs[#jobs + 1] = j
  end

  return cancel
end

---@param items lsp.CompletionItem[]
local function make_response(items)
  return { items = items, is_incomplete_forward = false, is_incomplete_backward = false }
end

function source:get_completions(_, callback)
  local now = vim.uv.hrtime()
  if self.cache and (now - self.cache.ts) < self.cache_ttl then
    return callback(make_response(copy_items(self.cache.items)))
  end

  local cancel = fetch_recent_panes(self.listen_on, function(text)
    local items = {}
    if #text > 0 then
      items = parse_items(text)
    end
    if #items > 0 then
      self.cache = { items = items, ts = vim.uv.hrtime() }
    end
    callback(make_response(copy_items(items)))
  end)

  return cancel
end

return source
