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

# 5. On-demand plugin cloning test
echo "=== lazy_ondemand tests ==="
FIXTURES="$CONF/tests/fixtures"

# Use NVIM_TEST=1 to redirect lockfile to cache dir (writable).
# Open a file so BufReadPre fires — plenary (BufReadPre) should auto-clone,
# virtcolumn (cmd-only) should not.
PLUGIN_DIR="$HOME/.local/share/nvim/lazy"
rm -rf "$PLUGIN_DIR/plenary.nvim" "$PLUGIN_DIR/virtcolumn.nvim"

NVIM_TEST=1 nvim --headless -u "$FIXTURES/minimal-plugins.lua" \
  +"qa!" \
  "$FIXTURES/test.sh"

if [ -d "$PLUGIN_DIR/plenary.nvim" ]; then
  echo "PASS: plenary.nvim auto-cloned on BufReadPre"
  PASS=$((PASS + 1))
else
  echo "FAIL: plenary.nvim not cloned"
  FAIL=$((FAIL + 1))
fi
# virtcolumn triggers on :VirtcolumnToggle command only — should not clone
if [ ! -d "$PLUGIN_DIR/virtcolumn.nvim" ]; then
  echo "PASS: virtcolumn.nvim correctly not cloned (cmd not run)"
  PASS=$((PASS + 1))
else
  echo "FAIL: virtcolumn.nvim cloned unexpectedly"
  FAIL=$((FAIL + 1))
fi

echo "---"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
