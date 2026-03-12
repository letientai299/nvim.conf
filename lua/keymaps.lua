-- Keymaps ported from vimrc / common.vim

local map = vim.keymap.set

local function lsp_buf(method, ...)
  local args = { ... }
  return function()
    return vim.lsp.buf[method](unpack(args))
  end
end

-- ---------------------------------------------------------------------------
-- Escape
-- ---------------------------------------------------------------------------

map("i", "jk", "<Esc>")
map("v", "jk", "<Esc>")
map("t", "<C-[><C-[>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

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
map({ "n", "v" }, "<Leader>y", [["+y]], { desc = "Copy to system clipboard" })
map(
  { "n", "v" },
  "<Leader>Y",
  [["+Y]],
  { desc = "Copy line to system clipboard" }
)

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
-- LSP actions
-- ---------------------------------------------------------------------------

map("n", "<Leader>ca", lsp_buf("code_action"), { desc = "Code action" })
map("n", "<Leader>cr", lsp_buf("rename"), { desc = "Rename" })
map("n", "<Leader>cf", lsp_buf("format", { async = true }), { desc = "Format" })

-- ---------------------------------------------------------------------------
-- Diagnostics
-- ---------------------------------------------------------------------------

map("n", "<Leader>dd", vim.diagnostic.open_float, { desc = "Line diagnostic" })
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
