local M = {}

--- True when nvim runs inside an SSH session. `SSH_TTY` is set for interactive
--- login shells; `SSH_CONNECTION` covers non-login/forced-command shells that
--- may lack a controlling tty. Either one means the local machine's clipboard is
--- unreachable through native tools, so OSC 52 is the only sync path.
---@return boolean
local function is_remote()
  return vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil
end

--- Route the `+`/`*` registers through OSC 52 when connected over SSH so yanks
--- land in the *local* machine's clipboard (the terminal emulator captures the
--- escape sequence and writes it), passing through tmux when `set-clipboard on`.
---
--- Only overrides `g:clipboard` on remote sessions. Locally, the native provider
--- (pbcopy/pbpaste on macOS) is faster and supports real read-back, so it is
--- left untouched.
---
--- Copy uses the built-in `vim.ui.clipboard.osc52` writer. Paste deliberately
--- returns nvim's own unnamed register instead of an OSC 52 read query: the read
--- path blocks for up to 10s waiting on a terminal response that tmux and most
--- terminals never send. Reading local clipboard *into* nvim is instead handled
--- naturally by the terminal's own paste (bracketed paste on Cmd/Ctrl-V). This
--- is the fallback pattern documented in `:h clipboard-osc52`.
function M.setup()
  if not is_remote() then
    return
  end

  local osc52 = require("vim.ui.clipboard.osc52")

  -- Paste from the unnamed register — a no-op round-trip that never blocks.
  local function paste()
    return vim.split(vim.fn.getreg('"'), "\n")
  end

  vim.g.clipboard = {
    name = "OSC 52 (ssh)",
    copy = {
      ["+"] = osc52.copy("+"),
      ["*"] = osc52.copy("*"),
    },
    paste = {
      ["+"] = paste,
      ["*"] = paste,
    },
  }
end

return M
