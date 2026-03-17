#!/usr/bin/env bash
# Capture a PNG screenshot of an e2e test's final nvim state.
#
# Usage: ./tests/capture.sh <distro> <ts|oil|starter> [settle-seconds]
#
# Runs the test container in tmux, waits for nvim to load, settles for plugins,
# then captures the tmux pane as a PNG via asciinema + agg.
#
# Output: .ai.dump/e2e/screenshots/<distro>-<test>.png
#
# Requirements: tmux, docker, asciinema, agg (with nerd fonts), run.sh
#
# Settle defaults: ts=5s, oil=30s, starter=5s. Override with the third argument.
set -euo pipefail

DISTRO="${1:?Usage: capture.sh <distro> <ts|oil|starter> [settle-seconds]}"
TEST="${2:?}"
SETTLE="${3:-}"

if [ -z "$SETTLE" ]; then
  case "$TEST" in
  ts) SETTLE=5 ;;
  oil) SETTLE=30 ;;
  starter) SETTLE=5 ;;
  *) SETTLE=10 ;;
  esac
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_DIR/.ai.dump/e2e/screenshots"
SESSION="ai-e2e-capture-${DISTRO}-${TEST}-$$"
TIMEOUT=300
POLL=2

NERD_FONT_DIR="${NERD_FONT_DIR:-$HOME/Library/Fonts}"
NERD_FONT_FAMILY="${NERD_FONT_FAMILY:-FiraCode Nerd Font Mono,Symbols Nerd Font Mono}"
AGG_THEME="1e1e2e,cdd6f4,45475a,f38ba8,a6e3a1,f9e2af,89b4fa,cba6f7,94e2d5,bac2de,585b70,f38ba8,a6e3a1,f9e2af,89b4fa,cba6f7,94e2d5,a6adc8"

mkdir -p "$OUTPUT_DIR"

# --- cleanup ----------------------------------------------------------------

cleanup() {
  tmux kill-session -t "$SESSION" 2>/dev/null || true
  docker rm -f "nvim-test-run-${DISTRO}" 2>/dev/null || true
}
trap cleanup EXIT

docker rm -f "nvim-test-run-${DISTRO}" 2>/dev/null || true
for _i in $(seq 1 10); do
  docker inspect "nvim-test-run-${DISTRO}" &>/dev/null || break
  sleep 1
done

# --- start container in tmux ------------------------------------------------

case "$TEST" in
ts) TCMD="./tests/run.sh -b -s 4 $DISTRO" ;;
oil) TCMD="./tests/run.sh -b -s 4 -x 'cd work && nvim .' $DISTRO" ;;
starter) TCMD="./tests/run.sh -b -s 4 -x nvim $DISTRO" ;;
*)
  echo "Unknown test type: $TEST" >&2
  exit 1
  ;;
esac

cd "$PROJECT_DIR"
tmux new-session -d -s "$SESSION" "$TCMD"
echo "Started $SESSION — waiting for nvim..."

# --- poll for nvim UI -------------------------------------------------------

elapsed=0
while [ "$elapsed" -lt "$TIMEOUT" ]; do
  sleep "$POLL"
  elapsed=$((elapsed + POLL))
  pane=$(tmux capture-pane -t "$SESSION" -p 2>/dev/null || true)

  if printf '%s' "$pane" | grep -q 'is not trusted'; then
    tmux send-keys -t "$SESSION" "a"
    sleep 2
    continue
  fi

  if printf '%s' "$pane" | grep -q 'Press ENTER'; then
    tmux send-keys -t "$SESSION" Enter
    sleep 1
    continue
  fi

  if printf '%s' "$pane" | grep -qE 'NORMAL|INSERT|VISUAL|─|oil://|MiniStarter|ministarter|[0-9]+\s+\.\./'; then
    echo "Nvim UI detected at +${elapsed}s — settling for ${SETTLE}s..."
    sleep "$SETTLE"
    break
  fi
done

if [ "$elapsed" -ge "$TIMEOUT" ]; then
  echo "ERROR: nvim did not load within ${TIMEOUT}s" >&2
  exit 1
fi

# --- capture ANSI → asciinema cast → PNG ------------------------------------

ANSI_FILE=$(mktemp)
CAST_FILE=$(mktemp)
tmux capture-pane -t "$SESSION" -p -e >"$ANSI_FILE"

asciinema rec --cols 80 --rows 24 --overwrite \
  -c "cat '$ANSI_FILE'" "$CAST_FILE" >/dev/null 2>&1

PNG_FILE="$OUTPUT_DIR/${DISTRO}-${TEST}.png"
agg --renderer fontdue \
  --font-dir "$NERD_FONT_DIR" --font-family "$NERD_FONT_FAMILY" \
  --theme "$AGG_THEME" \
  "$CAST_FILE" "$PNG_FILE"

rm -f "$ANSI_FILE" "$CAST_FILE"
echo "Saved $PNG_FILE"
