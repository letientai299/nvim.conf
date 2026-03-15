--- File index for project-wide path completion.
--- Maintains a sorted list of CompletionItems from git ls-files (or fallback),
--- with incremental patch/remove on buffer events.

local scanner = require("blink-cmp-path.scanner")

local Kind -- lazily resolved

--- Build a single CompletionItem from a relative path.
---@param rel string  relative path from project root
---@param cwd string  project root (captured at build time)
local function make_item(rel, cwd)
  Kind = Kind or require("blink.cmp.types").CompletionItemKind
  return {
    label = rel,
    kind = Kind.File,
    data = { full_path = cwd .. "/" .. rel },
  }
end

--- Binary search for the first item whose label >= prefix.
---@param items table[]
---@param prefix string
---@return number
local function lower_bound(items, prefix)
  local lo, hi = 1, #items + 1
  while lo < hi do
    local mid = math.floor((lo + hi) / 2)
    if items[mid].label < prefix then
      lo = mid + 1
    else
      hi = mid
    end
  end
  return lo
end

--- Find the start and end indices of items matching a prefix (sorted array).
--- Returns start, end (inclusive). Returns nil if no match.
---@param items table[]
---@param prefix string
---@return number?, number?
local function prefix_range(items, prefix)
  if #items == 0 or prefix == "" then
    return 1, #items
  end

  local start = lower_bound(items, prefix)
  if start > #items then
    return nil, nil
  end

  -- Compute the upper bound: first string that doesn't start with prefix.
  -- Increment the last byte of prefix to get the exclusive upper bound.
  local last = prefix:byte(#prefix)
  local upper
  if last < 255 then
    upper = prefix:sub(1, -2) .. string.char(last + 1)
  end

  local stop
  if upper then
    stop = lower_bound(items, upper) - 1
  else
    -- Edge case: last byte is 0xFF, scan forward
    stop = #items
  end

  if start > stop then
    return nil, nil
  end
  return start, stop
end

---@class blink-cmp-path.Index
---@field items table[]  sorted by label
---@field set table<string, true>
---@field cwd string?
---@field always_index string[]
local Index = {}
Index.__index = Index

---@param opts? { always_index?: string[] }
---@return blink-cmp-path.Index
function Index.new(opts)
  return setmetatable({
    items = {},
    set = {},
    cwd = nil,
    always_index = (opts and opts.always_index) or {},
  }, Index)
end

--- Full async rebuild. Replaces items atomically on completion.
---@param callback? fun()
---@return fun()? cancel
function Index:build(callback)
  local cwd = vim.uv.cwd()
  self.cwd = cwd

  local backend = scanner.detect_backend(cwd)
  local scan = backend == "git" and scanner.scan_git or scanner.scan_fd

  -- TODO: libuv walk fallback when neither git nor fd is available
  if backend == "walk" then
    self.items = {}
    self.set = {}
    if callback then
      callback()
    end
    return
  end

  return scan(cwd, function(paths)
    local function finish(all_paths)
      -- Deduplicate
      local set = {}
      local deduped = {}
      for _, rel in ipairs(all_paths) do
        if not set[rel] then
          set[rel] = true
          deduped[#deduped + 1] = rel
        end
      end

      -- Sort for binary search
      table.sort(deduped)

      -- Build items in sorted order
      local items = {}
      for i, rel in ipairs(deduped) do
        items[i] = make_item(rel, cwd)
      end

      self.items = items
      self.set = set
      if callback then
        callback()
      end
    end

    if #self.always_index > 0 then
      scanner.scan_glob(cwd, self.always_index, function(extra)
        vim.list_extend(paths, extra)
        finish(paths)
      end)
    else
      finish(paths)
    end
  end)
end

--- Incremental patch on BufWritePost. Adds new files or removes deleted ones.
---@param file string  absolute path of the file
function Index:patch(file)
  if not self.cwd then
    return
  end

  local prefix = self.cwd .. "/"
  if file:sub(1, #prefix) ~= prefix then
    return
  end
  local rel = file:sub(#prefix + 1)

  local stat = vim.uv.fs_stat(file)
  if stat and stat.type == "file" then
    if not self.set[rel] then
      self.set[rel] = true
      -- Insert in sorted position
      local pos = lower_bound(self.items, rel)
      table.insert(self.items, pos, make_item(rel, self.cwd))
    end
  else
    self:_swap_remove(rel)
  end
end

--- Remove a file from the index (BufDelete).
---@param file string  absolute path
function Index:remove(file)
  if not self.cwd then
    return
  end

  local prefix = self.cwd .. "/"
  if file:sub(1, #prefix) ~= prefix then
    return
  end
  self:_swap_remove(file:sub(#prefix + 1))
end

--- O(1) swap-remove + re-sort the swapped element into place.
--- Since we only move one element, a single comparison suffices after swap.
---@param rel string
function Index:_swap_remove(rel)
  if not self.set[rel] then
    return
  end
  self.set[rel] = nil

  local items = self.items
  local n = #items
  -- Find the item (binary search to the sorted position, then linear verify)
  local pos = lower_bound(items, rel)
  if pos > n or items[pos].label ~= rel then
    return
  end

  if pos == n then
    items[n] = nil
    return
  end

  -- Swap with last, remove last
  items[pos] = items[n]
  items[n] = nil

  -- Bubble the swapped element into sorted position
  -- It could be too large or too small for its current position
  local swapped = items[pos]
  -- Bubble right
  while pos < #items and swapped.label > items[pos + 1].label do
    items[pos], items[pos + 1] = items[pos + 1], items[pos]
    pos = pos + 1
  end
  -- Bubble left
  while pos > 1 and swapped.label < items[pos - 1].label do
    items[pos], items[pos - 1] = items[pos - 1], items[pos]
    pos = pos - 1
  end
end

--- Find items matching a directory prefix via binary search.
--- Returns a start index and end index (inclusive), or nil.
---@param dir_prefix string  e.g. "plugins/" or ""
---@return number?, number?
function Index:prefix_range(dir_prefix)
  return prefix_range(self.items, dir_prefix)
end

return Index
