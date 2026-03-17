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
resolve_nvim
trap cleanup_env EXIT

# Pre-warm vim.loader bytecode cache in the isolated env so bench numbers
# reflect real-world performance (warm cache) rather than cold-start penalty.
# Without this, the isolated XDG dirs have an empty vim.loader cache, adding
# ~9ms that doesn't exist in normal usage.
"$_PERF_NVIM" --headless +qa >/dev/null 2>&1 || true

# --- helpers ---

stats() {
  sort -n | awk '{
    a[NR] = $1
  }
  END {
    printf "%s %s %s", a[1], a[int((NR+1)/2)], a[NR]
  }'
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

  local min med max
  read -r min med max <<<"$(printf '%s\n' "${times[@]}" | stats)"
  printf '  %-30s %sms  (min=%s median=%s max=%s, %d runs)\n' \
    "$label" "$med" "$min" "$med" "$max" "${#times[@]}"
}

# --- cases ---

baseline_names=()
baseline_cmds=()

baseline_names+=("floor")
baseline_cmds+=("$_PERF_NVIM -u NONE --headless +qa")
baseline_names+=("bare")
baseline_cmds+=("$_PERF_NVIM +qa")
baseline_names+=("directory")
baseline_cmds+=("$_PERF_NVIM . +qa")

sample_names=()
sample_cmds=()

while IFS= read -r target; do
  sample_names+=("$(sample_label "$target")")
  sample_cmds+=("$_PERF_NVIM $target +qa")
done < <(sample_targets)

# --- run ---

printf 'Benchmark: %d runs per case\n' "$RUNS"
printf 'Binary: %s\n\n' "$_PERF_NVIM"

if command -v hyperfine >/dev/null 2>&1; then
  printf '=== hyperfine mode ===\n\n'

  # Group 1: baselines (floor, bare, directory)
  printf '%s\n' '--- baselines ---'
  hf_baseline_args=()
  for i in "${!baseline_names[@]}"; do
    hf_baseline_args+=(--command-name "${baseline_names[$i]}" "${baseline_cmds[$i]}")
  done
  hyperfine --runs "$RUNS" --warmup 3 -N \
    "${hf_baseline_args[@]}" \
    2>&1 | sed 's/^/    /'
  echo

  # Group 2: all sample files
  printf '%s\n' '--- sample files ---'
  hf_sample_args=()
  for i in "${!sample_names[@]}"; do
    hf_sample_args+=(--command-name "${sample_names[$i]}" "${sample_cmds[$i]}")
  done
  hyperfine --runs "$RUNS" --warmup 3 -N \
    "${hf_sample_args[@]}" \
    2>&1 | sed 's/^/    /'
else
  printf '=== manual mode (hyperfine not found) ===\n\n'

  printf '%s\n' '--- baselines ---'
  for i in "${!baseline_names[@]}"; do
    # shellcheck disable=SC2086
    manual_bench "${baseline_names[$i]}" ${baseline_cmds[$i]}
  done
  echo

  printf '%s\n' '--- sample files ---'
  for i in "${!sample_names[@]}"; do
    # shellcheck disable=SC2086
    manual_bench "${sample_names[$i]}" ${sample_cmds[$i]}
  done
fi

printf '\nDone\n'
