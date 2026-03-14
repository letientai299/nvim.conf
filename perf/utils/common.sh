#!/usr/bin/env bash
# Shared setup for perf scripts: isolated XDG dirs, lockfile copy, cleanup.
# Source this — do not execute directly.

set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'error: %s not found\n' "$1" >&2
    exit 1
  }
}

# setup_isolated_env [config-tree]
#   config-tree defaults to $REPO_ROOT
#   Exports NVIM_TEST, XDG_CONFIG_HOME, XDG_CACHE_HOME, XDG_STATE_HOME
#   Sets _PERF_CLEANUP_DIRS for cleanup_env
setup_isolated_env() {
  local tree="${1:-$REPO_ROOT}"

  _PERF_CFG="$(mktemp -d /tmp/nvim-bench-cfg.XXXXXX)"
  _PERF_CACHE="$(mktemp -d /tmp/nvim-bench-cache.XXXXXX)"
  _PERF_STATE="$(mktemp -d /tmp/nvim-bench-state.XXXXXX)"
  _PERF_CLEANUP_DIRS="$_PERF_CFG $_PERF_CACHE $_PERF_STATE"

  ln -s "$tree" "$_PERF_CFG/nvim"

  # Copy lockfile so lazy.nvim doesn't attempt a sync.
  # NVIM_TEST=1 redirects the lockfile to $XDG_CACHE_HOME/nvim/lazy-lock.json.
  mkdir -p "$_PERF_CACHE/nvim"
  cp "$tree/lazy-lock.json" "$_PERF_CACHE/nvim/lazy-lock.json"

  # Copy exrc trust data so headful nvim doesn't prompt for .nvim.lua trust.
  local real_state="${XDG_STATE_HOME:-$HOME/.local/state}"
  if [[ -f "$real_state/nvim/trust" ]]; then
    mkdir -p "$_PERF_STATE/nvim"
    cp "$real_state/nvim/trust" "$_PERF_STATE/nvim/trust"
  fi

  export NVIM_TEST=1
  export XDG_CONFIG_HOME="$_PERF_CFG"
  export XDG_CACHE_HOME="$_PERF_CACHE"
  export XDG_STATE_HOME="$_PERF_STATE"
}

cleanup_env() {
  # shellcheck disable=SC2086
  rm -rf ${_PERF_CLEANUP_DIRS:-}
}

# extract_startup_ms <startuptime-log>
#   Prints the final "NVIM STARTED" time in milliseconds.
#   Returns empty string if the log doesn't contain NVIM STARTED (crash/timeout).
extract_startup_ms() {
  awk '/NVIM STARTED/ { ms = $1 } END { if (ms != "") print ms }' "$1"
}
