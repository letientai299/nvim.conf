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

function M.copy_file()
  if is_remote() or vim.fn.has("mac") == 0 then
    vim.notify("File clipboard requires local macOS", vim.log.levels.WARN)
    return
  end
  local path = vim.api.nvim_buf_get_name(0)
  if vim.bo.buftype ~= "" or vim.fn.filereadable(path) == 0 then
    vim.notify("Current buffer has no readable file", vim.log.levels.WARN)
    return
  end
  if vim.bo.modified then
    vim.notify("Save changes before copying the file", vim.log.levels.WARN)
    return
  end

  local script = [[
ObjC.import('AppKit');
function run(argv) {
  const url = $.NSURL.fileURLWithPath(argv[0]);
  const clipboard = $.NSPasteboard.generalPasteboard;
  clipboard.clearContents;
  if (!clipboard.writeObjects($.NSArray.arrayWithObject(url))) {
    throw new Error('File clipboard write failed');
  }
}
]]
  vim.system(
    { "/usr/bin/osascript", "-l", "JavaScript", "-e", script, path },
    { text = true },
    function(result)
      vim.schedule(function()
        if result.code ~= 0 then
          vim.notify(
            "File copy failed: " .. vim.trim(result.stderr),
            vim.log.levels.ERROR
          )
          return
        end
        vim.notify("File copied to clipboard")
      end)
    end
  )
end

return M
