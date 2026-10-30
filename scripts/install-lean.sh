#!/usr/bin/env bash
set -euo pipefail

elan_dir="${ELAN_HOME:-$HOME/.elan}"
if [ "${TOOL_INSTALLER_FORCE:-0}" != "1" ] && [ -x "$elan_dir/bin/lean" ]; then
  exit 0
fi

installer=$(mktemp)
trap 'rm -f "$installer"' EXIT
curl -fsSL https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -o "$installer"
sh "$installer" -y --no-modify-path --default-toolchain leanprover/lean4:stable
