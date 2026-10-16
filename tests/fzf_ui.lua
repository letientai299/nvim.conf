vim.opt.rtp:prepend(vim.fn.getcwd())
local directory = vim.fn.tempname()
local stdpath = vim.fn.stdpath
vim.fn.stdpath = function(kind)
  return kind == "state" and directory or stdpath(kind)
end
local ui = require("lib.fzf_ui")
vim.fn.stdpath = stdpath
local path = directory .. "/store/fzf-ui.json"
local current
package.loaded["fzf-lua.win"] = {
  __SELF = function()
    return current
  end,
}

local function open(overrides)
  local opts = vim.tbl_deep_extend("force", ui.winopts(), overrides or {})
  current = {
    winopts = opts,
    _o = {},
    on_closes = {},
    previewer_is_builtin = true,
    fullscreen = opts.fullscreen or false,
    preview_hidden = opts.preview.hidden or false,
    preview_wrap = opts.preview.wrap or false,
    position = opts.preview[opts.preview.layout]:match("^%a+"),
    size = opts.preview[opts.preview.layout]:match(":(.+)$"),
    normalize_preview_layout = function(self)
      return { pos = self.position, str = self.position .. ":" .. self.size }
    end,
  }
  opts.on_create()
  return current
end

local win = open()
assert(win.position == "up", "Initial preview position changed")
win.on_closes.fzf_ui()
assert(vim.fn.filereadable(path) == 0, "Unchanged picker saved state")
win = open()
win.fullscreen = true
win.preview_hidden = true
win.preview_wrap = true
win.position = "left"
win.size = "65%"
win.winopts.on_create()
win.on_closes.fzf_ui()
package.loaded["lib.fzf_ui"] = nil
vim.fn.stdpath = function()
  return directory
end
ui = require("lib.fzf_ui")
vim.fn.stdpath = stdpath
win = open()
assert(
  win.fullscreen and win.preview_hidden and win.preview_wrap,
  "Saved flags missing"
)
assert(win.position == "left", "Saved position missing")
assert(win.size == "65%", "Saved preview size missing")
win = open({ fullscreen = false, preview = { hidden = false } })
win.on_closes.fzf_ui()
win = open()
assert(
  win.fullscreen and win.preview_hidden,
  "Picker overrides replaced saved flags"
)
win.fullscreen = false
win.preview_hidden = false
win.preview_wrap = false
win.position = "down"
win.on_closes.fzf_ui()
win = open()
assert(
  not win.fullscreen and not win.preview_hidden and not win.preview_wrap,
  "False flags lost"
)
assert(win.position == "down", "Vertical rotation missing")
vim.fn.writefile({ '{"position":"left","wrap":true}' }, path)
win = open()
assert(win.position == "left" and win.size == "50%", "Legacy position lost")
assert(win.preview_wrap, "Legacy wrap lost")
vim.fn.writefile({ '{"position":"right:80"}' }, path)
win = open()
assert(
  win.position == "right" and win.size == "80",
  "Absolute preview size lost"
)
for _, position in ipairs({ "right:0", "right:101%", "up:abc", "other:50%" }) do
  vim.fn.writefile({ vim.json.encode({ position = position }) }, path)
  assert(open().position == "up", "Invalid preview size loaded")
end
vim.fn.writefile({ "invalid json" }, path)
assert(open().position == "up", "Corrupt state broke defaults")
vim.fn.writefile(
  { '{"position":[],"hidden":"yes","fullscreen":1,"wrap":{}}' },
  path
)
win = open()
assert(
  not win.fullscreen and not win.preview_hidden and not win.preview_wrap,
  "Invalid flags loaded"
)
assert(win.position == "up", "Invalid position loaded")
vim.fn.delete(directory, "rf")
print("Fzf UI persistence passed")
