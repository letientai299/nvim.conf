local fallback_config = require("lib.fallback_config")

local M = {}

--- Prettier config file names for project detection.
--- Does not include package.json (needs content inspection) — prettier's own
--- config discovery handles that case when cwd points to the project root.
--- @type FallbackSpec
M.fallback_spec = {
  names = {
    ".prettierrc",
    ".prettierrc.json",
    ".prettierrc.yml",
    ".prettierrc.yaml",
    ".prettierrc.json5",
    ".prettierrc.js",
    ".prettierrc.cjs",
    ".prettierrc.mjs",
    ".prettierrc.ts",
    ".prettierrc.toml",
    "prettier.config.js",
    "prettier.config.cjs",
    "prettier.config.mjs",
    "prettier.config.ts",
  },
  flag = "--config",
  fallback = vim.fn.stdpath("config") .. "/configs/prettierrc.yml",
}

--- @return tool-installer.Tool
function M.tool()
  return {
    bin = "prettier",
    mise = "npm:prettier",
    dependencies = { "node" },
  }
end

--- Build a conform.nvim spec that maps filetypes to prettier.
--- @param fts string|string[]
--- @return table lazy.nvim plugin spec
function M.conform(fts)
  if type(fts) == "string" then
    fts = { fts }
  end
  local by_ft = {}
  for _, ft in ipairs(fts) do
    by_ft[ft] = { "prettier" }
  end
  return {
    "stevearc/conform.nvim",
    opts = { formatters_by_ft = by_ft },
  }
end

-- ---------------------------------------------------------------------------
-- Resolve printWidth from prettier config (async, cached)
-- ---------------------------------------------------------------------------

--- Set textwidth on a buffer.
--- vim.bo doesn't fire OptionSet, so we also schedule a :setlocal to notify
--- listeners (e.g. virtcolumn.nvim) that need OptionSet to re-resolve
--- colorcolumn. The immediate vim.bo ensures textwidth takes effect without
--- waiting for the next event-loop tick.
--- @param buf integer
--- @param tw number
local function set_textwidth(buf, tw)
  vim.bo[buf].textwidth = tw
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].textwidth == tw then
      vim.api.nvim_buf_call(buf, function()
        vim.cmd("setlocal textwidth=" .. tw)
      end)
    end
  end)
end

--- Check whether `path` is inside a project that has a prettier config.
--- Extends has_project_config with a package.json "prettier" key check.
--- @param path string
--- @return boolean
local function has_prettier_config(path)
  if fallback_config.has_project_config(M.fallback_spec, path) then
    return true
  end
  -- Check package.json for "prettier" key
  local root = vim.fs.root(path, "package.json")
  if not root then
    return false
  end
  local pkg_path = root .. "/package.json"
  local stat = vim.uv.fs_stat(pkg_path)
  if not stat then
    return false
  end
  local fd = vim.uv.fs_open(pkg_path, "r", 438)
  if not fd then
    return false
  end
  local data = vim.uv.fs_read(fd, stat.size, 0)
  vim.uv.fs_close(fd)
  if not data then
    return false
  end
  local ok, pkg = pcall(vim.json.decode, data)
  return ok and pkg and pkg.prettier ~= nil
end

-- Fresh batches also reload imported JavaScript modules.
local RESOLVE_SCRIPT = [[
const p = require('path'), f = require('fs');
const d = p.dirname(f.realpathSync(process.argv[1]));
const prettier = require(require.resolve('prettier', {paths: [d]}));
const files = JSON.parse(f.readFileSync(0, 'utf8'));
Promise.all(files.map(async file => {
  try {
    const config = await prettier.resolveConfig(file);
    const width = config?.printWidth;
    return [file, Number.isInteger(width) && width > 0 ? width : false];
  } catch {
    return [file, null];
  }
})).then(entries => process.stdout.write('\nNVIM_PRETTIER:' + JSON.stringify(Object.fromEntries(entries))));
]]

local cache = {}
local pending = {}
local inflight = {}
local buffers = {}
local generation = 0
local scheduled = false
local process
local closing = false

local function apply_width(buf, file, width)
  if
    not vim.api.nvim_buf_is_valid(buf)
    or vim.api.nvim_buf_get_name(buf) ~= file
  then
    return
  end
  local state = buffers[buf]
  if not state or state.file ~= file then
    return
  end
  if width then
    if state.applied == nil or vim.bo[buf].textwidth ~= state.applied then
      state.original = vim.bo[buf].textwidth
    end
    state.applied = width
    set_textwidth(buf, width)
  elseif state.applied then
    if vim.bo[buf].textwidth == state.applied then
      set_textwidth(buf, state.original)
    end
    state.applied = nil
  end
end

local run_batch
local function schedule_batch()
  if not scheduled then
    scheduled = true
    vim.defer_fn(run_batch, 50)
  end
end

local function apply_batch(batch, result)
  if result.code ~= 0 or result.signal ~= 0 then
    return
  end
  local payload = (result.stdout or ""):match("\nNVIM_PRETTIER:(.*)$")
  local decoded, widths = pcall(vim.json.decode, payload or "")
  if not decoded or type(widths) ~= "table" then
    return
  end
  for file, waiting in pairs(batch) do
    local width = widths[file]
    if
      width == false
      or (type(width) == "number" and width > 0 and width % 1 == 0)
    then
      cache[file] = width
      for buf in pairs(waiting) do
        apply_width(buf, file, width)
      end
    end
  end
end

run_batch = function()
  scheduled = false
  if closing or process or not next(pending) then
    return
  end
  local batch = pending
  pending = {}
  local prettier = vim.fn.exepath("prettier")
  if prettier == "" or vim.fn.executable("node") ~= 1 then
    return
  end
  local epoch = generation
  inflight = batch
  local ok, job = pcall(
    vim.system,
    { "node", "-e", RESOLVE_SCRIPT, prettier },
    {
      text = true,
      stdin = vim.json.encode(vim.tbl_keys(batch)),
      timeout = 5000,
    },
    vim.schedule_wrap(function(result)
      if epoch ~= generation or closing then
        return
      end
      process = nil
      inflight = {}
      if next(pending) then
        schedule_batch()
      end
      apply_batch(batch, result)
    end)
  )
  if ok then
    process = job
  else
    inflight = {}
  end
end

function M.resolve_print_width(buf)
  if
    closing
    or not vim.api.nvim_buf_is_loaded(buf)
    or vim.bo[buf].buftype ~= ""
  then
    return
  end
  local file = vim.api.nvim_buf_get_name(buf)
  if file == "" then
    return
  end
  if not buffers[buf] or buffers[buf].file ~= file then
    buffers[buf] = { file = file }
  end
  if cache[file] ~= nil then
    apply_width(buf, file, cache[file])
    return
  end
  if not has_prettier_config(file) then
    cache[file] = false
    apply_width(buf, file, false)
    return
  end
  if inflight[file] then
    inflight[file][buf] = true
    return
  end
  pending[file] = pending[file] or {}
  pending[file][buf] = true
  schedule_batch()
end

local function invalidate()
  generation = generation + 1
  cache = {}
  pending = {}
  inflight = {}
  if process then
    process:kill(15)
    process = nil
  end
  for buf in pairs(buffers) do
    if vim.api.nvim_buf_is_loaded(buf) then
      M.resolve_print_width(buf)
    else
      buffers[buf] = nil
    end
  end
end

local group = vim.api.nvim_create_augroup("PrettierCache", { clear = true })
vim.api.nvim_create_autocmd(
  { "BufWritePost", "FileChangedShellPost", "FocusGained", "DirChanged" },
  {
    group = group,
    callback = invalidate,
  }
)
vim.api.nvim_create_autocmd("BufWipeout", {
  group = group,
  callback = function(ev)
    buffers[ev.buf] = nil
  end,
})
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = group,
  callback = function()
    closing = true
    generation = generation + 1
    if process then
      process:kill(15)
    end
  end,
})

return M
