#!/usr/bin/env bash
# Run e2e tests across distros: TS highlighting, Oil file browser, MiniStarter.
#
# Usage:
#   ./tests/e2e.sh                   # all distros, all tests
#   ./tests/e2e.sh ubuntu fedora     # specific distros
#
# Each test boots a container via run.sh -b, waits for nvim UI, verifies the
# feature, captures a PNG screenshot, and checks :messages/:Notifications for
# errors.
#
# Output:
#   .ai.dump/e2e/screenshots/<distro>-<test>.png
#   .ai.dump/e2e/evidence/<distro>-<test>.{txt,messages,notifications}
#   .ai.dump/e2e/results.txt
#
# Requirements: tmux, docker, asciinema, agg (with nerd fonts)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_DIR/.ai.dump/e2e"
SCREENSHOT_DIR="$OUTPUT_DIR/screenshots"
EVIDENCE_DIR="$OUTPUT_DIR/evidence"
RESULTS_FILE="$OUTPUT_DIR/results.txt"

TIMEOUT=180
POLL=2

# --- font / theme config ---------------------------------------------------

# Override NERD_FONT_DIR to point at a directory containing .ttf nerd fonts.
NERD_FONT_DIR="${NERD_FONT_DIR:-$HOME/Library/Fonts}"
NERD_FONT_FAMILY="${NERD_FONT_FAMILY:-FiraCode Nerd Font Mono,Symbols Nerd Font Mono}"

# Catppuccin Mocha: bg, fg, then 16 ANSI colors. Matches nvim's colorscheme
# so agg's default background doesn't create seams where tmux ANSI capture
# has partial background coverage.
AGG_THEME="1e1e2e,cdd6f4,45475a,f38ba8,a6e3a1,f9e2af,89b4fa,cba6f7,94e2d5,bac2de,585b70,f38ba8,a6e3a1,f9e2af,89b4fa,cba6f7,94e2d5,a6adc8"

mkdir -p "$SCREENSHOT_DIR" "$EVIDENCE_DIR"

# --- distro discovery -------------------------------------------------------

ALL_DISTROS=()
for df in "$PROJECT_DIR/tests/infra"/*.Dockerfile; do
  name="${df##*/}"
  ALL_DISTROS+=("${name%.Dockerfile}")
done

DISTROS=("${@:-${ALL_DISTROS[@]}}")
if [ $# -eq 0 ]; then DISTROS=("${ALL_DISTROS[@]}"); fi

TESTS=(ts oil starter)

# --- helpers ----------------------------------------------------------------

settle_for() {
  case "$1" in
  ts) echo 0 ;; # TS uses its own poll loop
  oil) echo 30 ;;
  starter) echo 0 ;; # starter uses its own poll loop
  *) echo 10 ;;
  esac
}

tmux_cmd() {
  local distro=$1 test=$2
  case "$test" in
  ts) echo "./tests/run.sh -b -s 4 $distro" ;;
  oil) echo "./tests/run.sh -b -s 4 -x 'cd work && nvim .' $distro" ;;
  starter) echo "./tests/run.sh -b -s 4 -x nvim $distro" ;;
  esac
}

wait_container_gone() {
  local name=$1
  docker rm -f "$name" 2>/dev/null || true
  for _i in $(seq 1 15); do
    docker inspect "$name" &>/dev/null || return 0
    sleep 1
  done
  echo "WARN: container $name still exists after 15s" >&2
}

nvim_exec() {
  local session=$1 cmd=$2 wait=${3:-2}
  tmux send-keys -t "$session" Escape
  sleep 0.3
  tmux send-keys -t "$session" ":$cmd" Enter
  sleep "$wait"
  tmux capture-pane -t "$session" -p 2>/dev/null || true
}

capture_png() {
  local session=$1 output=$2
  local ansi cast
  ansi=$(mktemp)
  cast=$(mktemp)
  tmux capture-pane -t "$session" -p -e >"$ansi"
  asciinema rec --cols 80 --rows 24 --overwrite \
    -c "cat '$ansi'" "$cast" >/dev/null 2>&1
  agg --renderer fontdue \
    --font-dir "$NERD_FONT_DIR" --font-family "$NERD_FONT_FAMILY" \
    --theme "$AGG_THEME" \
    "$cast" "$output" >/dev/null 2>&1
  rm -f "$ansi" "$cast"
}

# Match nvim error patterns, exclude normal plugin install noise.
has_errors() {
  local text=$1
  printf '%s' "$text" | grep -iE \
    'E[0-9]+:|error detected|stack traceback|failed to load|exception|traceback' \
    2>/dev/null | grep -qivE 'installed\.|Installing\.|checking\.|built\.' 2>/dev/null
}

# --- poll for nvim UI -------------------------------------------------------

# Shared poll loop: waits for nvim to appear, handles trust and "Press ENTER"
# prompts. Sets ready=true and returns 0 on success, 1 on timeout.
poll_nvim_ui() {
  local session=$1
  local elapsed=0
  while [ "$elapsed" -lt "$TIMEOUT" ]; do
    sleep "$POLL"
    elapsed=$((elapsed + POLL))
    local pane
    pane=$(tmux capture-pane -t "$session" -p 2>/dev/null || true)

    if printf '%s' "$pane" | grep -q 'is not trusted'; then
      tmux send-keys -t "$session" "a"
      sleep 2
      continue
    fi

    if printf '%s' "$pane" | grep -q 'Press ENTER'; then
      tmux send-keys -t "$session" Enter
      sleep 1
      continue
    fi

    # oil:// matches before lualine loads. After lualine's oil extension
    # activates, the statusline shows ~/work/ instead. Detect the oil
    # directory listing (numbered ../ entry) as a fallback.
    if printf '%s' "$pane" | grep -qE 'NORMAL|INSERT|VISUAL|─|oil://|MiniStarter|ministarter|[0-9]+\s+\.\./'; then
      return 0
    fi
  done
  return 1
}

# --- test verifiers ---------------------------------------------------------

verify_ts() {
  local session=$1
  local ts_timeout=60 ts_poll=3 ts_elapsed=0
  while [ "$ts_elapsed" -lt "$ts_timeout" ]; do
    tmux send-keys -t "$session" Escape
    sleep 0.3
    tmux send-keys -t "$session" \
      ":lua print(pcall(vim.treesitter.get_parser) and 'TS_WORKS' or 'TS_NOPE')" Enter
    sleep 2
    local pane
    pane=$(tmux capture-pane -t "$session" -p 2>/dev/null || true)
    if printf '%s' "$pane" | grep -q "TS_WORKS"; then
      echo "PASS|TS parser active (+${ts_elapsed}s)"
      return
    fi
    if printf '%s' "$pane" | grep -q 'Press ENTER'; then
      tmux send-keys -t "$session" Enter
      sleep 1
    fi
    sleep "$ts_poll"
    ts_elapsed=$((ts_elapsed + ts_poll + 2))
  done
  echo "FAIL|TS parser not ready after ${ts_timeout}s"
}

verify_oil() {
  local session=$1
  local pane
  pane=$(tmux capture-pane -t "$session" -p 2>/dev/null || true)
  if printf '%s' "$pane" | grep -qiE '(lua|scripts|tests|README|init)'; then
    echo "PASS|Oil with files listed"
  else
    echo "FAIL|No project files visible"
  fi
}

verify_starter() {
  local session=$1
  local pane ok=false

  pane=$(tmux capture-pane -t "$session" -p 2>/dev/null || true)
  if printf '%s' "$pane" | grep -qiE 'ministarter://|Good evening|Recent files|Actions'; then
    ok=true
  else
    # Default intro showing — lazy.nvim hasn't fired VeryLazy yet.
    tmux send-keys -t "$session" Enter
    sleep 1
    local wait=0 max=30
    while [ "$wait" -lt "$max" ]; do
      pane=$(tmux capture-pane -t "$session" -p 2>/dev/null || true)
      if printf '%s' "$pane" | grep -qiE 'ministarter://|Good evening|Recent files|Actions'; then
        ok=true
        break
      fi
      if printf '%s' "$pane" | grep -q 'Press ENTER'; then
        tmux send-keys -t "$session" Enter
      fi
      sleep 2
      wait=$((wait + 2))
    done
  fi

  if $ok; then
    echo "PASS|MiniStarter active"
  elif printf '%s' "$pane" | grep -qE 'NVIM v|Help poor children'; then
    echo "FAIL|Default intro after 30s (starter never loaded)"
  else
    echo "FAIL|Unknown state"
  fi
}

# --- run a single test ------------------------------------------------------

run_test() {
  local distro=$1 test=$2
  local session="ai-e2e-${distro}-${test}-$$"
  local container="nvim-test-run-${distro}"
  local settle
  settle=$(settle_for "$test")

  tmux kill-session -t "$session" 2>/dev/null || true
  wait_container_gone "$container" 2>/dev/null

  local tcmd
  tcmd=$(tmux_cmd "$distro" "$test")
  cd "$PROJECT_DIR" || return
  tmux new-session -d -s "$session" -x 80 -y 24 "$tcmd"

  if ! poll_nvim_ui "$session"; then
    tmux capture-pane -t "$session" -p >"$EVIDENCE_DIR/${distro}-${test}.txt" 2>/dev/null || true
    tmux kill-session -t "$session" 2>/dev/null || true
    wait_container_gone "$container" 2>/dev/null
    echo "${distro}|${test}|FAIL|timeout ${TIMEOUT}s"
    return
  fi

  sleep "$settle"

  # Step 1: verify
  local verdict
  case "$test" in
  ts) verdict=$(verify_ts "$session") ;;
  oil) verdict=$(verify_oil "$session") ;;
  starter) verdict=$(verify_starter "$session") ;;
  esac
  local result="${verdict%%|*}"
  local details="${verdict#*|}"

  # Step 2: screenshot
  capture_png "$session" "$SCREENSHOT_DIR/${distro}-${test}.png"
  tmux capture-pane -t "$session" -p >"$EVIDENCE_DIR/${distro}-${test}.txt" 2>/dev/null || true

  # Step 3: check :messages and :Notifications
  local messages notifications
  messages=$(nvim_exec "$session" "messages" 2)
  printf '%s\n' "$messages" >"$EVIDENCE_DIR/${distro}-${test}.messages"
  tmux send-keys -t "$session" Escape
  sleep 0.3
  notifications=$(nvim_exec "$session" "Notifications" 2)
  printf '%s\n' "$notifications" >"$EVIDENCE_DIR/${distro}-${test}.notifications"

  local msg_errors="" notif_errors=""
  if has_errors "$messages"; then
    msg_errors=$(printf '%s' "$messages" | grep -iE 'E[0-9]+:|error detected|stack traceback|failed to load|exception|traceback' | head -3)
  fi
  if has_errors "$notifications"; then
    notif_errors=$(printf '%s' "$notifications" | grep -iE 'E[0-9]+:|error detected|stack traceback|failed to load|exception|traceback' | head -3)
  fi
  if [ -n "$msg_errors" ] || [ -n "$notif_errors" ]; then
    if [ "$result" = "PASS" ]; then result="WARN"; fi
    [ -n "$msg_errors" ] && details="$details; msgs: $(echo "$msg_errors" | tr '\n' ' ' | head -c 120)"
    [ -n "$notif_errors" ] && details="$details; notifs: $(echo "$notif_errors" | tr '\n' ' ' | head -c 120)"
  fi

  tmux kill-session -t "$session" 2>/dev/null || true
  wait_container_gone "$container" 2>/dev/null

  echo "${distro}|${test}|${result}|${details}"
}

# --- main -------------------------------------------------------------------

echo "distro|test|result|details" >"$RESULTS_FILE"

total=${#DISTROS[@]}
current=0
for distro in "${DISTROS[@]}"; do
  current=$((current + 1))
  for test in "${TESTS[@]}"; do
    printf '\033[1;34m==>\033[0m [%d/%d] %s %s\n' "$current" "$total" "$distro" "$test" >&2
    line=$(run_test "$distro" "$test")
    echo "$line" | tee -a "$RESULTS_FILE"
  done
done

echo "" >&2
echo "=== Summary ===" >&2
column -t -s'|' "$RESULTS_FILE" >&2
echo "" >&2
echo "Screenshots: $SCREENSHOT_DIR/" >&2
echo "Evidence:    $EVIDENCE_DIR/" >&2
echo "Results:     $RESULTS_FILE" >&2
