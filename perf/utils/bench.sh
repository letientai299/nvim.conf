#!/usr/bin/env bash
# Benchmark nvim startup across all cases in perf/samples/.
#
# Two modes:
#   hyperfine mode — when hyperfine is available (wall-clock, statistical)
#   manual mode    — fallback: N runs, parse --startuptime, compute median
#
# Does NOT use --headless for normal cases (matches real startup with UIEnter).
# Uses --headless only for the -u NONE floor baseline.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
source "$SCRIPT_DIR/common.sh"

RUNS="${BENCH_RUNS:-20}"

setup_isolated_env
trap cleanup_env EXIT

# --- helpers ---

median() {
  sort -n | awk '{a[NR]=$1} END {print a[int((NR+1)/2)]}'
}

manual_bench() {
  local label="$1"
  shift
  local times=()
  local log
  log="$(mktemp /tmp/nvim-bench-log.XXXXXX)"

  for ((i = 1; i <= RUNS; i++)); do
    "$@" --startuptime "$log" +qa >/dev/null 2>&1
    local ms
    ms="$(extract_startup_ms "$log")"
    if [[ -n "$ms" ]]; then
      times+=("$ms")
    fi
  done
  rm -f "$log"

  if ((${#times[@]} == 0)); then
    printf '  %-30s FAIL (no valid runs)\n' "$label"
    return 1
  fi

  local med
  med="$(printf '%s\n' "${times[@]}" | median)"
  printf '  %-30s %sms (median of %d runs)\n' "$label" "$med" "${#times[@]}"
}

# --- cases ---

cases=()
cases+=("bare|nvim")
cases+=("directory|nvim .")

for f in "$REPO_ROOT"/perf/samples/*; do
  cases+=("$(basename "$f")|nvim|$f")
done

# --- run ---

printf 'Benchmark: %d runs per case\n\n' "$RUNS"

env_args=(
  env
  "NVIM_TEST=1"
  "XDG_CONFIG_HOME=$_PERF_CFG"
  "XDG_CACHE_HOME=$_PERF_CACHE"
  "XDG_STATE_HOME=$_PERF_STATE"
)

if command -v hyperfine >/dev/null 2>&1; then
  printf '=== hyperfine mode ===\n\n'

  printf '%s\n' '--- floor (nvim -u NONE --headless) ---'
  hyperfine --runs "$RUNS" --warmup 3 \
    --command-name "floor" \
    "env XDG_CACHE_HOME='${_PERF_CACHE}' XDG_STATE_HOME='${_PERF_STATE}' nvim -u NONE --headless +qa" \
    2>&1 | sed 's/^/    /'
  echo

  printf '%s\n' '--- normal cases ---'
  for entry in "${cases[@]}"; do
    IFS='|' read -r label cmd file <<<"$entry"
    if [[ -n "$file" ]]; then
      bench_cmd="env NVIM_TEST=1 XDG_CONFIG_HOME='${_PERF_CFG}' XDG_CACHE_HOME='${_PERF_CACHE}' XDG_STATE_HOME='${_PERF_STATE}' $cmd '$file' +qa"
    else
      bench_cmd="env NVIM_TEST=1 XDG_CONFIG_HOME='${_PERF_CFG}' XDG_CACHE_HOME='${_PERF_CACHE}' XDG_STATE_HOME='${_PERF_STATE}' $cmd +qa"
    fi
    hyperfine --runs "$RUNS" --warmup 3 \
      --command-name "$label" \
      "$bench_cmd" \
      2>&1 | sed 's/^/    /'
  done
else
  printf '=== manual mode (hyperfine not found) ===\n\n'

  printf '%s\n' '--- floor (nvim -u NONE --headless) ---'
  manual_bench "floor" \
    env "XDG_CACHE_HOME=$_PERF_CACHE" "XDG_STATE_HOME=$_PERF_STATE" \
    nvim -u NONE --headless
  echo

  printf '%s\n' '--- normal cases ---'
  for entry in "${cases[@]}"; do
    IFS='|' read -r label cmd file <<<"$entry"
    if [[ -n "$file" ]]; then
      manual_bench "$label" "${env_args[@]}" "$cmd" "$file"
    else
      # shellcheck disable=SC2086
      manual_bench "$label" "${env_args[@]}" $cmd
    fi
  done
fi

printf '\nDone\n'
