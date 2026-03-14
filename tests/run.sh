#!/usr/bin/env bash
set -euo pipefail

# Repo is mounted read-only at /opt/nvim-conf. Copy to ~/.config/nvim so mise
# and lazy.nvim can write to ~/.config/ freely.
REPO=/opt/nvim-conf
CONF=~/.config/nvim
mkdir -p ~/.config
cp -r "$REPO" "$CONF"

PASS=0
FAIL=0

assert_bin() {
  if command -v "$1" &>/dev/null; then
    echo "PASS: $1 installed"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $1 missing"
    FAIL=$((FAIL + 1))
  fi
}

# 1. Run bootstrap (skips config clone since ~/.config/nvim already exists)
"$CONF/scripts/install.sh"

# 2. Add mise paths (skip auto-install of project tools during test)
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
export MISE_INSTALL_AUTO=0

# 3. Verify bootstrap installed global tools
for bin in mise git nvim fzf fd rg bat; do
  assert_bin "$bin"
done

# 4. Basic nvim launch
nvim --headless +qa
echo "PASS: nvim launches cleanly"
PASS=$((PASS + 1))

echo "---"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
