#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NVIM_CONFIG="${HOME}/.config/nvim"

install_mise() {
  if command -v mise >/dev/null 2>&1; then
    return
  fi
  echo "==> Installing mise..."
  curl -fsSL https://mise.jdx.dev/install.sh | sh
}

install_tools() {
  echo "==> Installing mise project tools..."
  mise install
  echo "==> Syncing language tools..."
  mise run sync
}

link_config() {
  if [ -e "$NVIM_CONFIG" ] && [ ! -L "$NVIM_CONFIG" ]; then
    echo "ERROR: $NVIM_CONFIG exists and is not a symlink. Back it up first."
    exit 1
  fi
  mkdir -p "$(dirname "$NVIM_CONFIG")"
  ln -sfn "$REPO_DIR" "$NVIM_CONFIG"
  echo "==> Linked $NVIM_CONFIG -> $REPO_DIR"
}

install_mise
install_tools
link_config
