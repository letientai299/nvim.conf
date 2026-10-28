vim.opt.rtp:prepend(vim.fn.getcwd() .. "/plugins/kitty-send.nvim")
vim.env.KITTY_LISTEN_ON = "unix:test"
vim.env.KITTY_WINDOW_ID = "1"
local original_system = vim.system
local original_select = vim.ui.select
local selected, sent, activated, errors = {}, {}, {}, {}
local missing, fail, plain, cancel = false, false, false, false
local processes = { { pid = 123, cmdline = { "tmux", "-L", "test" } } }
vim.notify = function(msg, level)
  if level == vim.log.levels.ERROR then
    errors[#errors + 1] = msg
  end
end
vim.ui.select = function(items, opts, callback)
  selected[#selected + 1] = opts.prompt
  callback(not cancel and items[#items] or nil)
end
vim.system = function(cmd, opts)
  local result = { code = 0, stdout = "", stderr = "" }
  if cmd[1] == "tmux" then
    assert(cmd[2] == "-L" and cmd[3] == "test", "Wrong tmux server")
    if cmd[4] == "list-clients" then
      result.stdout = "999\t%9\t/dev/other\n123\t%1\t/dev/test\n"
    elseif cmd[4] == "list-panes" then
      result.stdout = missing and "%1\t0\tzsh\n"
        or "%1\t0\tzsh\n%2\t1\tpython\n"
    elseif cmd[4] == "list-commands" then
      result.stdout = "display-panes [-t target-pane]"
    elseif cmd[4] == "display-panes" then
      assert(cmd[6] == "%1", "Wrong overlay target")
    elseif cmd[4] == "display-message" or cmd[4] == "set-option" then
      result.stdout = ""
    elseif cmd[4] == "show-options" then
      result.stdout = cancel and "" or "%2\n"
    elseif cmd[4] == "select-pane" then
      activated[#activated + 1] = cmd[6]
      result.code = fail and 1 or 0
    else
      error("Unexpected tmux command")
    end
  elseif cmd[5] == "ls" then
    result.stdout = vim.json.encode({
      {
        tabs = {
          {
            windows = {
              { id = 1 },
              {
                id = 2,
                title = "shell",
                foreground_processes = plain and {} or processes,
              },
              { id = 3, title = "other" },
            },
          },
        },
      },
    })
  elseif cmd[5] == "select-window" then
    result.stdout = "2"
  elseif cmd[5] == "send-text" then
    sent[#sent + 1] = opts and opts.stdin or cmd[#cmd]
  elseif cmd[5] == "focus-window" then
    result.stdout = ""
  else
    error("Unexpected Kitty command")
  end
  return {
    wait = function()
      return result
    end,
  }
end
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "print('hello')", "" })
local plugin = require("kitty-send")
plugin.send({})
assert(#selected == 0, "Tmux used a list picker")
assert(
  activated[1] == "%2" and sent[1] == "print('hello')" and sent[2] == "\r",
  "Wrong pane or payload"
)
plugin.send({ bang = true })
assert(#selected == 0 and activated[2] == "%2", "Bang lost tmux target")
missing = true
plugin.send({ bang = true })
assert(activated[3] == "%1", "Stale target fallback failed")
missing = false
cancel = true
local count = #sent
plugin.send({ fargs = { "2" } })
assert(#sent == count, "Cancellation sent input")
cancel = false
fail = true
plugin.send({ fargs = { "2" } })
assert(#sent == count and #errors == 1, "Selection failure sent input")
fail = false
plain = true
plugin.send({ fargs = { "2" } })
assert(#sent == count + 2, "Plain Kitty delivery failed")
plugin.setup({ picker = "select" })
plugin.send({})
assert(selected[#selected] == "Send to Kitty pane:", "Kitty picker missing")
vim.system = original_system
vim.ui.select = original_select
print("Kitty send tests passed")
