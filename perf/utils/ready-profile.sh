#!/usr/bin/env bash
# Measure runtime syntax, treesitter, and LSP readiness for a target file.
# Runs nvim headfully because UIEnter must fire.
#
# Usage: ready-profile.sh <target> [-o output]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
source "$SCRIPT_DIR/common.sh"

target=""
output=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  -o)
    output="$2"
    shift 2
    ;;
  *)
    target="$1"
    shift
    ;;
  esac
done

if [[ -z "$target" ]]; then
  printf 'usage: %s <target> [-o output]\n' "$(basename "$0")" >&2
  exit 1
fi

setup_isolated_env
resolve_nvim
trap cleanup_env EXIT

profile_out="${output:-$(mktemp /tmp/ready-profile.XXXXXX)}"
check_lua="$(mktemp /tmp/nvim-ready-profile-XXXXXX)"
mv "$check_lua" "$check_lua.lua"
check_lua="$check_lua.lua"

cat >"$check_lua" <<'LUAEOF'
local out = vim.env.READY_OUT
local deadline_ms = tonumber(vim.env.READY_TIMEOUT_MS) or 3000
local buf
local started
local deadline
local ts_ms
local lsp_ms
local seen_clients = {}

local function add_client(id)
  if type(id) ~= "number" then
    return
  end

  local client = vim.lsp.get_client_by_id(id)
  if client and client.name then
    seen_clients[client.name] = true
  end
end

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    if not buf or args.buf ~= buf then
      return
    end

    add_client(args.data and args.data.client_id or nil)
    if not lsp_ms and started then
      lsp_ms = (vim.uv.hrtime() - started) / 1e6
    end
  end,
})

vim.api.nvim_create_autocmd("UIEnter", {
  once = true,
  callback = function()
    buf = vim.api.nvim_get_current_buf()
    started = vim.uv.hrtime()
    deadline = started + deadline_ms * 1e6
    local ui_current_syntax = tostring(vim.b[buf].current_syntax)
    local ui_ts_highlight = tostring(vim.b[buf].ts_highlight)
    local ui_ts_active = tostring(vim.treesitter.highlighter.active[buf] ~= nil)

    local function client_names()
      local names = {}
      for name in pairs(seen_clients) do
        names[#names + 1] = name
      end
      table.sort(names)
      return table.concat(names, ",")
    end

    for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
      seen_clients[client.name] = true
    end
    if next(seen_clients) ~= nil then
      lsp_ms = 0
    end

    local function poll()
      local now = vim.uv.hrtime()
      if not ts_ms and vim.b[buf].ts_highlight then
        ts_ms = (now - started) / 1e6
      end

      if (ts_ms and lsp_ms) or now >= deadline then
        vim.fn.writefile({
          "ui_current_syntax=" .. ui_current_syntax,
          "ui_ts_highlight=" .. ui_ts_highlight,
          "ui_ts_active=" .. ui_ts_active,
          ("ts_ready_ms=%.2f"):format(ts_ms or -1),
          ("lsp_ready_ms=%.2f"):format(lsp_ms or -1),
          "clients=" .. client_names(),
        }, out)
        vim.cmd("qa!")
        return
      end

      vim.defer_fn(poll, 10)
    end

    poll()
  end,
})
LUAEOF

export READY_OUT="$profile_out"
export READY_TIMEOUT_MS="${READY_TIMEOUT_MS:-3000}"

"$_PERF_NVIM" "$target" -S "$check_lua" >/dev/null 2>&1
cat "$profile_out"

rm -f "$check_lua"
if [[ -z "$output" ]]; then
  rm -f "$profile_out"
fi
