--- blink.cmp source: project-wide fuzzy path completion.
---
--- Indexes all files via `git ls-files` (or `fd` fallback) and returns
--- pre-built CompletionItems for blink's fuzzy engine. Stays current via
--- autocommands (FocusGained, DirChanged, BufWritePost, BufDelete).

local Index = require("blink-cmp-path.index")

local PREVIEW_LINES = 10
local DEBOUNCE_NS = 5e9 -- 5 seconds in nanoseconds

--- @module 'blink.cmp'
--- @class blink.cmp.Source
local source = {}

--- Extract the path-like WORD before cursor. Returns nil if no `/` present.
---@param context table
---@return string?  directory prefix up to last `/` (e.g. "plugins/")
local function get_dir_prefix(context)
  local word = context.line:sub(1, context.cursor[2]):match("%S+$")
  if not word or not word:find("/") then
    return nil
  end
  return word:match("^(.*/)") or ""
end

local EMPTY =
  { items = {}, is_incomplete_forward = false, is_incomplete_backward = false }

--- @param opts? { always_index?: string[] }
function source.new(opts)
  local self = setmetatable({}, { __index = source })
  self.index = Index.new(opts)
  self.cancel_build = nil
  self.last_build_time = 0

  -- Initial build
  self:_build()

  -- Autocommands
  local group = vim.api.nvim_create_augroup("blink-cmp-path", { clear = true })

  vim.api.nvim_create_autocmd({ "FocusGained", "DirChanged" }, {
    group = group,
    callback = function()
      local now = vim.uv.hrtime()
      if (now - self.last_build_time) < DEBOUNCE_NS then
        return
      end
      self:_build()
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    callback = function(ev)
      local file = ev.match
      if file and file ~= "" then
        self.index:patch(vim.fn.fnamemodify(file, ":p"))
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(ev)
      local file = vim.api.nvim_buf_get_name(ev.buf)
      if file and file ~= "" then
        self.index:remove(file)
      end
    end,
  })

  -- Manual refresh command
  vim.api.nvim_create_user_command("PathCmpRefresh", function()
    self:_build(function()
      vim.notify(
        ("PathCmpRefresh: indexed %d files"):format(#self.index.items),
        vim.log.levels.INFO
      )
    end)
  end, { desc = "Rebuild blink-cmp-path index" })

  -- One-time fsmonitor recommendation
  if not vim.g.blink_cmp_path_fsmonitor_checked then
    vim.g.blink_cmp_path_fsmonitor_checked = true
    vim.defer_fn(function()
      local cwd = vim.uv.cwd()
      if not cwd or not vim.uv.fs_stat(cwd .. "/.git") then
        return
      end
      local result = vim
        .system({ "git", "config", "core.fsmonitor" }, { text = true })
        :wait()
      if result.code ~= 0 or vim.trim(result.stdout or "") ~= "true" then
        vim.notify(
          "blink-cmp-path: consider enabling core.fsmonitor for faster git ls-files\n"
            .. "  git config core.fsmonitor true\n"
            .. "  git config core.untrackedCache true",
          vim.log.levels.INFO
        )
      end
    end, 2000)
  end

  return self
end

--- Cancel any in-flight build and start a new one.
---@param callback? fun()
function source:_build(callback)
  if self.cancel_build then
    self.cancel_build()
    self.cancel_build = nil
  end
  self.cancel_build = self.index:build(function()
    self.cancel_build = nil
    self.last_build_time = vim.uv.hrtime()
    if callback then
      callback()
    end
  end)
end

function source:enabled()
  return true
end

function source:get_trigger_characters()
  return { "/" }
end

function source:get_completions(context, callback)
  local dir_prefix = get_dir_prefix(context)
  if not dir_prefix then
    return callback(EMPTY)
  end

  local items = self.index.items
  local start, stop = self.index:prefix_range(dir_prefix)
  if not start then
    return callback(EMPTY)
  end

  -- Copy the matching slice — blink mutates items in-place
  local out = {}
  for i = start, stop do
    local it = items[i]
    out[#out + 1] = { label = it.label, kind = it.kind, data = it.data }
  end

  return callback({
    items = out,
    is_incomplete_forward = true,
    is_incomplete_backward = true,
  })
end

--- Read first N lines of the file for documentation preview.
function source:resolve(item, callback)
  local full_path = item.data and item.data.full_path
  if not full_path then
    return callback(item)
  end

  local stat = vim.uv.fs_stat(full_path)
  if not stat or stat.type ~= "file" then
    return callback(item)
  end

  local fd = vim.uv.fs_open(full_path, "r", 438) -- 0666
  if not fd then
    return callback(item)
  end

  local size = math.min(stat.size, 4096)
  local data = vim.uv.fs_read(fd, size, 0)
  vim.uv.fs_close(fd)

  if not data or #data == 0 then
    return callback(item)
  end

  local lines = {}
  for line in data:gmatch("[^\n]*") do
    lines[#lines + 1] = line
    if #lines >= PREVIEW_LINES then
      break
    end
  end

  local ft = vim.filetype.match({ filename = full_path }) or ""

  item.documentation = {
    kind = "markdown",
    value = ("```%s\n%s\n```"):format(ft, table.concat(lines, "\n")),
  }
  callback(item)
end

return source
