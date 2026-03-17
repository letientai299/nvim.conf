#!/usr/bin/env bash
# Verify config boots cleanly before benchmarking.
#
# Runs two rounds:
#   1. Headless — catches init errors fast (no terminal needed).
#   2. Headful  — verifies UIEnter-dependent paths (lazy.nvim, colorscheme,
#      autocmds). A terminal window opens briefly per case.
#
# Both rounds must pass before benchmarks are trustworthy.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
source "$SCRIPT_DIR/common.sh"

setup_isolated_env
resolve_nvim
trap cleanup_env EXIT

failures=0

run_case() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf '  OK   %s\n' "$label"
  else
    printf '  FAIL %s\n' "$label"
    ((failures++)) || true
  fi
}

# --- Round 1: headless (fast, catches init errors) ---

printf 'Round 1: headless boot\n'
run_case "bare" "$_PERF_NVIM" --headless +qa
run_case "directory" "$_PERF_NVIM" --headless . +qa

while IFS= read -r target; do
  run_case "$(sample_label "$target")" "$_PERF_NVIM" --headless "$target" +qa
done < <(sample_targets)

# --- Round 2: headful (UIEnter fires, lazy.nvim loads) ---
# Plain +qa races with UIEnter — lazy.nvim hooks into UIEnter and blocks the
# quit. Source a temp lua file to avoid shell-quoting issues.

quit_lua="$(mktemp /tmp/nvim-quit-XXXXXX)"
mv "$quit_lua" "$quit_lua.lua"
quit_lua="$quit_lua.lua"
cat >"$quit_lua" <<'LUAEOF'
vim.api.nvim_create_autocmd("User", {
  pattern = "LazyVimStarted",
  once = true,
  callback = function()
    vim.cmd("qa!")
  end,
})
LUAEOF

printf '\nRound 2: headful boot (terminal window opens briefly)\n'
run_case "bare" "$_PERF_NVIM" -S "$quit_lua"
run_case "directory" "$_PERF_NVIM" . -S "$quit_lua"

while IFS= read -r target; do
  run_case "$(sample_label "$target")" "$_PERF_NVIM" "$target" -S "$quit_lua"
done < <(sample_targets)
rm -f "$quit_lua"

# --- Result ---

if ((failures > 0)); then
  printf '\n%d case(s) failed — fix before benchmarking\n' "$failures" >&2
  exit 1
fi
printf '\nAll cases passed\n'
