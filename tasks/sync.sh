#!/usr/bin/env bash
set -euo pipefail

# --- Mise tools ---
# Read tool specs from tools.txt and install globally in one call (parallel).
echo "==> Syncing mise tools to global config..."
# shellcheck disable=SC2046
mise use -g $(grep -v '^\s*#' tools.txt | grep -v '^\s*$' | sed 's/$/@latest/')

# --- Brew packages (no mise backend available) ---
echo "==> Installing brew packages..."
if command -v brew &>/dev/null; then
  brew install pgformatter
else
  echo "  SKIP: brew not found"
fi

echo "==> Done."
