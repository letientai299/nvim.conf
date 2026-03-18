-- Deferred keymaps that are not needed for the first painted frame.

local map = vim.keymap.set

local function lsp_buf(method, ...)
  local args = { ... }
  return function()
    return vim.lsp.buf[method](unpack(args))
  end
end

-- Free <C-q> from its built-in <C-v> alias so mini-clue can use it as a
-- terminal prefix trigger.
map("n", "<C-q>", "<Nop>")

-- ---------------------------------------------------------------------------
-- System clipboard
-- ---------------------------------------------------------------------------

map(
  { "n", "v" },
  "<Leader>p",
  [["+p]],
  { desc = "Paste from system clipboard" }
)
map(
  { "n", "v" },
  "<Leader>P",
  [["+P]],
  { desc = "Paste before from system clipboard" }
)
map({ "n", "v" }, "<Leader>yy", [["+y]], { desc = "Copy to system clipboard" })
map(
  { "n", "v" },
  "<Leader>yY",
  [["+Y]],
  { desc = "Copy line to system clipboard" }
)

-- ---------------------------------------------------------------------------
-- Buffer quit
-- ---------------------------------------------------------------------------

map("n", "<Leader>qq", "<Cmd>bd<CR>", { desc = "Quit current buffer" })
map("n", "<Leader>qt", "<Cmd>tabclose<CR>", { desc = "Quit current tab" })

-- ---------------------------------------------------------------------------
-- Center after search
-- ---------------------------------------------------------------------------

map("n", "n", "nzz")
map("n", "N", "Nzz")
map("n", "*", "*zz")
map("n", "#", "#zz")

-- ---------------------------------------------------------------------------
-- Cmdline history navigation
-- ---------------------------------------------------------------------------

map("c", "<C-p>", "<Up>")
map("c", "<C-n>", "<Down>")

-- ---------------------------------------------------------------------------
-- Create file from path under cursor
-- ---------------------------------------------------------------------------

--- Create the file under cursor if it doesn't exist, then open it.
local function create_file()
  local path = vim.fn.expand("<cfile>")
  if path == "" then
    return
  end
  if not vim.uv.fs_stat(path) then
    local dir = vim.fn.fnamemodify(path, ":h")
    if dir ~= "." and not vim.uv.fs_stat(dir) then
      vim.fn.mkdir(dir, "p")
    end
  end
  vim.cmd.edit(path)
end

map(
  "n",
  "<Leader>cn",
  create_file,
  { desc = "Create file from path under cursor" }
)
map("n", "<Leader>w", "<Cmd>Dirsv<CR>", { desc = "Dirsv" })

-- ---------------------------------------------------------------------------
-- File navigation (prev/next in same directory)
-- ---------------------------------------------------------------------------

--- Get sorted sibling files, return the path offset by `delta` from current.
local function sibling_file(delta)
  local cur = vim.api.nvim_buf_get_name(0)
  if cur == "" then
    return
  end
  local dir = vim.fn.fnamemodify(cur, ":h")
  local entries = {}
  for name, type in vim.fs.dir(dir) do
    if type == "file" then
      entries[#entries + 1] = name
    end
  end
  table.sort(entries)
  local base = vim.fn.fnamemodify(cur, ":t")
  for i, name in ipairs(entries) do
    if name == base then
      local target = entries[((i - 1 + delta) % #entries) + 1]
      vim.cmd.edit(dir .. "/" .. target)
      return
    end
  end
end

map("n", "[f", function()
  sibling_file(-1)
end, { desc = "Previous file in directory" })
map("n", "]f", function()
  sibling_file(1)
end, { desc = "Next file in directory" })

-- ---------------------------------------------------------------------------
-- Config editing / reloading
-- ---------------------------------------------------------------------------

local config_root = vim.fn.stdpath("config") --[[@as string]]

--- Find the nearest .nvim.lua from cwd up to git root, or return git root path.
local function find_project_exrc()
  local root = vim.fs.root(0, ".git") or vim.uv.cwd()
  local found = vim.fs.find(".nvim.lua", {
    upward = true,
    path = vim.uv.cwd(),
    stop = vim.fn.fnamemodify(root, ":h"),
  })
  if found[1] then
    return found[1]
  end
  return root .. "/.nvim.lua"
end

map("n", "<Leader>vl", function()
  vim.cmd.edit(config_root .. "/lua/local/init.lua")
end, { desc = "Edit machine-local config" })

map("n", "<Leader>vp", function()
  vim.cmd.edit(find_project_exrc())
end, { desc = "Edit project .nvim.lua" })

map("n", "<Leader>va", function()
  local local_cfg = config_root .. "/lua/local/local.lua"
  if vim.uv.fs_stat(local_cfg) then
    vim.cmd.source(local_cfg)
  end
  local exrc = find_project_exrc()
  if vim.uv.fs_stat(exrc) then
    vim.cmd.source(exrc)
  end
  vim.notify("Reloaded local configs")
end, { desc = "Reload local + project config" })

-- ---------------------------------------------------------------------------
-- LSP actions
-- ---------------------------------------------------------------------------

map("n", "<Leader>ca", lsp_buf("code_action"), { desc = "Code action" })
map("n", "<Leader>cr", lsp_buf("rename"), { desc = "Rename" })
map("n", "<Leader>cf", lsp_buf("format", { async = true }), { desc = "Format" })

-- ---------------------------------------------------------------------------
-- Diagnostics
-- ---------------------------------------------------------------------------

map("n", "<Leader>dd", function()
  vim.diagnostic.open_float()
end, { desc = "Line diagnostic" })
map("n", "<Leader>dl", function()
  vim.diagnostic.setloclist()
end, { desc = "Diagnostic loclist" })
map("n", "<Leader>dq", function()
  vim.diagnostic.setqflist()
end, { desc = "Diagnostic quickfix" })

-- ---------------------------------------------------------------------------
-- Go to (LSP)
-- ---------------------------------------------------------------------------

map("n", "gd", lsp_buf("definition"), { desc = "Go to definition" })
map("n", "gD", lsp_buf("declaration"), { desc = "Go to declaration" })
map("n", "gi", lsp_buf("implementation"), { desc = "Go to implementation" })
map("n", "gI", lsp_buf("type_definition"), { desc = "Go to type definition" })
