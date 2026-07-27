--- Send the current buffer (or a visual selection) to another Kitty window
--- (pane) that shares the same Kitty tab as neovim.
---
--- Uses kitty's remote control: `kitty @ ls` to discover sibling panes and
--- `kitty @ send-text` to deliver the text. When more than one target pane is
--- visible, the destination is chosen with kitty's native selection overlay
--- (`kitty @ select-window`, which draws a number over each pane) or, when
--- `picker = "select"`, with `vim.ui.select`.
---
--- Requires `allow_remote_control` and `listen_on` in kitty.conf. The command
--- reports an error when KITTY_LISTEN_ON or KITTY_WINDOW_ID is unset.

local M = {}

-- Remembered destination pane id, reused by `:KittySend!`.
local last_target = nil

--- @class kitty-send.Config
--- @field picker "kitty"|"select"  Target picker when >1 sibling pane exists.
---   "kitty" draws kitty's native numbered overlay on each pane
---   (`kitty @ select-window`); "select" uses `vim.ui.select`.
local config = {
  picker = "kitty",
}

--- @param opts? kitty-send.Config
function M.setup(opts)
  config = vim.tbl_extend("force", config, opts or {})
end

--- @class kitty-send.Pane
--- @field id number      Kitty window (pane) id.
--- @field title string   Window title, shown in the picker.

--- Resolve kitty's remote-control socket and neovim's own window id.
--- @return string? listen_on
--- @return number? self_id
--- @return string? err
local function kitty_env()
  local listen_on = vim.env.KITTY_LISTEN_ON
  local self_id = tonumber(vim.env.KITTY_WINDOW_ID)
  if not listen_on or not self_id then
    return nil, nil, "not running inside a Kitty window with remote control"
  end
  return listen_on, self_id
end

--- List sibling panes: every window in neovim's tab except neovim itself.
--- @param listen_on string
--- @param self_id number
--- @return kitty-send.Pane[]? panes
--- @return string? err
local function sibling_panes(listen_on, self_id)
  local res = vim
    .system({ "kitty", "@", "--to", listen_on, "ls" }, { text = true })
    :wait()
  if res.code ~= 0 then
    return nil, (res.stderr ~= "" and res.stderr or "kitty @ ls failed")
  end

  local ok, tree = pcall(vim.json.decode, res.stdout)
  if not ok or type(tree) ~= "table" then
    return nil, "could not parse kitty @ ls output"
  end

  for _, os_window in ipairs(tree) do
    for _, tab in ipairs(os_window.tabs or {}) do
      local in_this_tab = false
      for _, w in ipairs(tab.windows or {}) do
        if w.id == self_id then
          in_this_tab = true
          break
        end
      end
      if in_this_tab then
        local panes = {}
        for _, w in ipairs(tab.windows or {}) do
          if w.id ~= self_id then
            panes[#panes + 1] = { id = w.id, title = w.title or "" }
          end
        end
        return panes
      end
    end
  end

  return {}
end

--- Deliver text to a pane as a bracketed paste, then a carriage return so the
--- final line is submitted (e.g. executed in a shell or REPL).
---
--- Bracketed paste is what makes multi-line text survive a target running tmux.
--- Sent raw, the whole payload arrives as one fast burst; tmux forwards it as
--- individual keystrokes, so the embedded newlines act as Enter and the lines
--- collapse — you see only a blank line land. Wrapping the payload in bracketed
--- paste escapes makes tmux (and the inner shell) treat it as a single paste.
--- `--bracketed-paste=auto` only wraps when the target program has bracketed
--- paste mode on (a shell/REPL prompt), so raw programs are unaffected.
---
--- The carriage return that submits the command MUST be sent as a separate,
--- unwrapped keystroke: inside the paste it would be inserted as a literal
--- newline (a multi-line command buffer) instead of executing.
--- @param listen_on string
--- @param id number
--- @param text string
--- @return boolean ok
--- @return string? err
local function send_text(listen_on, id, text)
  text = text:gsub("[\r\n]+$", "")
  local match = "id:" .. id
  local paste = vim
    .system({
      "kitty",
      "@",
      "--to",
      listen_on,
      "send-text",
      "--match",
      match,
      "--bracketed-paste",
      "auto",
      "--stdin",
    }, { stdin = text, text = true })
    :wait()
  if paste.code ~= 0 then
    return false,
      (paste.stderr ~= "" and paste.stderr or "kitty @ send-text failed")
  end
  local enter = vim
    .system({
      "kitty",
      "@",
      "--to",
      listen_on,
      "send-text",
      "--match",
      match,
      "\r",
    }, { text = true })
    :wait()
  if enter.code ~= 0 then
    return false,
      (enter.stderr ~= "" and enter.stderr or "kitty @ send-text failed")
  end
  return true
end

--- Collect the payload: the visual selection when invoked with a range,
--- otherwise the whole buffer.
--- @param opts table  User-command callback options.
--- @return string
local function payload(opts)
  if opts.range and opts.range > 0 then
    local mode = vim.fn.visualmode()
    if mode ~= "" then
      local ok, region = pcall(
        vim.fn.getregion,
        vim.fn.getpos("'<"),
        vim.fn.getpos("'>"),
        { type = mode }
      )
      if ok and region and #region > 0 then
        return table.concat(region, "\n")
      end
    end
    -- Fall back to linewise range if getregion is unavailable.
    local lines =
      vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false)
    return table.concat(lines, "\n")
  end
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  return table.concat(lines, "\n")
end

--- Pick a target pane visually using kitty's native overlay
--- (`kitty @ select-window`), which draws a number/letter over each pane in
--- the tab and blocks until the user presses a key. `--exclude-active` drops
--- neovim's own (active) pane from the choices. Prints the chosen id.
--- @param listen_on string
--- @return number? id   Selected window id; nil if cancelled or on error.
--- @return string? err
local function pick_native(listen_on)
  local res = vim
    .system({
      "kitty",
      "@",
      "--to",
      listen_on,
      "select-window",
      "--self",
      "--exclude-active",
    }, { text = true })
    :wait()
  local id = tonumber((res.stdout or ""):match("%d+"))
  if id then
    return id
  end
  -- No id: distinguish a user cancellation from a real error. A clean abort
  -- (Esc) exits 0; waiting past --response-timeout exits non-zero with a
  -- "Timed out" message. Both mean "no selection" — stay silent. Anything
  -- else (e.g. connection failure) is surfaced.
  if res.code == 0 or (res.stderr or ""):match("[Tt]imed out") then
    return nil
  end
  return nil,
    (res.stderr ~= "" and res.stderr or "kitty @ select-window failed")
end

--- Send `text` to `pane`, remembering it for `:KittySend!`.
local function deliver(listen_on, pane, text)
  local ok, err = send_text(listen_on, pane.id, text)
  if not ok then
    vim.notify("KittySend: " .. err, vim.log.levels.ERROR)
    return
  end
  last_target = pane.id
  vim.notify(
    ("KittySend: sent to pane %d%s"):format(
      pane.id,
      pane.title ~= "" and (" (" .. pane.title .. ")") or ""
    ),
    vim.log.levels.INFO
  )
end

--- Entry point for the `:KittySend[!]` command.
--- @param opts table  User-command callback options.
function M.send(opts)
  local listen_on, self_id, err = kitty_env()
  if not listen_on then
    vim.notify("KittySend: " .. err, vim.log.levels.ERROR)
    return
  end

  local panes, list_err = sibling_panes(listen_on, self_id --[[@as number]])
  if not panes then
    vim.notify("KittySend: " .. list_err, vim.log.levels.ERROR)
    return
  end
  if #panes == 0 then
    vim.notify(
      "KittySend: no other Kitty panes in this tab",
      vim.log.levels.WARN
    )
    return
  end

  local text = payload(opts)

  -- Bang reuses the last target if it is still a valid sibling.
  if opts.bang and last_target then
    for _, p in ipairs(panes) do
      if p.id == last_target then
        deliver(listen_on, p, text)
        return
      end
    end
  end

  if #panes == 1 then
    deliver(listen_on, panes[1], text)
    return
  end

  local by_id = {}
  for _, p in ipairs(panes) do
    by_id[p.id] = p
  end

  if config.picker == "kitty" then
    local id, err2 = pick_native(listen_on)
    if err2 then
      vim.notify("KittySend: " .. err2, vim.log.levels.ERROR)
      return
    end
    if not id then
      return -- user aborted
    end
    if id == self_id then
      vim.notify(
        "KittySend: cannot send to neovim's own pane",
        vim.log.levels.WARN
      )
      return
    end
    deliver(listen_on, by_id[id] or { id = id, title = "" }, text)
    return
  end

  vim.ui.select(panes, {
    prompt = "Send to Kitty pane:",
    format_item = function(p)
      local label = ("pane %d"):format(p.id)
      if p.title ~= "" then
        label = label .. "  " .. p.title
      end
      if p.id == last_target then
        label = label .. "  (last)"
      end
      return label
    end,
  }, function(choice)
    if choice then
      deliver(listen_on, choice, text)
    end
  end)
end

return M
