#!/usr/bin/env bash
# Capture lazy.nvim's per-plugin profile tree and stats.
# Runs nvim non-headlessly (UIEnter must fire for lazy.nvim timing).
# A terminal window opens briefly per invocation.
#
# Usage: lazy-profile.sh [target] [-o output]
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

setup_isolated_env
resolve_nvim
trap cleanup_env EXIT

profile_out="${output:-$(mktemp /tmp/lazy-profile.XXXXXX)}"
export PROFILE_OUT="$profile_out"

# The Lua callback reads vim.env.PROFILE_OUT, dumps the tree, and quits.
# NOTE: Util._profiles is lazy.nvim internal API (underscore prefix).
# It may break on lazy.nvim updates. The script degrades gracefully — stats
# still print, only the profile tree is lost.
lua_cmd='
vim.api.nvim_create_autocmd("User", {
  pattern = "LazyVimStarted",
  once = true,
  callback = function()
    local stats = require("lazy").stats()
    local ok, Util = pcall(require, "lazy.core.util")
    local out = {
      ("startuptime=%.2fms real=%s count=%d loaded=%d"):format(
        stats.startuptime, tostring(stats.real_cputime), stats.count, stats.loaded
      ),
    }
    for k, v in pairs(stats.times or {}) do
      out[#out + 1] = ("  %-20s %.2fms"):format(k, v * 1000)
    end
    out[#out + 1] = ""
    if ok and Util._profiles and Util._profiles[1] then
      local function walk(e, d)
        if e.time / 1e6 < 0.5 then return end
        local lbl = type(e.data) == "string" and e.data
          or vim.inspect(e.data):gsub("%s+", " ")
        out[#out + 1] = string.rep("  ", d) .. ("[%.2fms] %s"):format(e.time / 1e6, lbl)
        for _, c in ipairs(e) do walk(c, d + 1) end
      end
      for _, e in ipairs(Util._profiles[1]) do walk(e, 0) end
    end
    vim.fn.writefile(vim.split(table.concat(out, "\n"), "\n"), vim.env.PROFILE_OUT)
    vim.cmd("qa!")
  end,
})
'

# Run without --headless so UIEnter fires.
# shellcheck disable=SC2086
"$_PERF_NVIM" +"lua $lua_cmd" ${target:+"$target"} >/dev/null 2>&1

cat "$profile_out"

if [[ -z "$output" ]]; then
  rm -f "$profile_out"
fi
