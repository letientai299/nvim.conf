#!/usr/bin/env bash
# Select a test Dockerfile via fzf, build, and run with the project mounted.
#
# Usage:
#   ./tests/run.sh                # fzf-select one distro, build & run with proxy
#   ./tests/run.sh ub             # pre-filter fzf with "ub", auto-pick if one match
#   ./tests/run.sh -b ub          # build, run, install, source, open nvim
#   ./tests/run.sh -x ub          # skip proxy, direct network
#   ./tests/run.sh -s 4 ub        # replay cached responses 4x faster
#   ./tests/run.sh --build        # build all images (no interactive run)
#   ./tests/run.sh --pull         # pull latest base images
#   ./tests/run.sh --clear-cache  # wipe proxy cache
#   ./tests/run.sh -bs20 --check  # boot + automated smoke test
#   ./tests/run.sh -h             # show this help
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INFRA_DIR="$SCRIPT_DIR/infra"
PROXY_DIR="$SCRIPT_DIR/proxy"
PROXY_PORT="${PROXY_PORT:-8090}"

logf() { printf '\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }

usage() {
  cat <<'EOF'
Usage: ./tests/run.sh [flags] [filter]

Flags:
  -b, --boot         Build, run, install, source bashrc, open nvim
  -c, --check        With -b: run automated smoke test instead of interactive shell
  -x, --bypass       Skip proxy, direct network access
  -s, --speed N      Replay cached responses N times faster (e.g., -s 4)
  -t, --timeout N    Kill container after N seconds (default: 120 with --check)
      --build        Build all test images (no interactive run)
      --pull         Pull latest base images
      --clear-cache  Wipe proxy cache directory
  -h, --help         Show this help

Arguments:
  filter             Substring to match distro name (auto-selects if unique)
EOF
}

resolve_base_digest() {
  # Pin the FROM image to its local digest so BuildKit skips the registry
  # metadata check (~2s). Falls back to the tag if not pulled locally.
  local dockerfile=$1
  local base
  base=$(sed -n 's/^ARG BASE_IMAGE=\(.*\)/\1/p' "$dockerfile" | head -1)
  local digest
  digest=$(docker inspect --format='{{index .RepoDigests 0}}' "$base" 2>/dev/null || true)
  if [[ -n "$digest" ]]; then
    printf '%s' "$digest"
  else
    printf '%s' "$base"
  fi
}

build_image() {
  local name=$1
  local dockerfile="$INFRA_DIR/${name}.Dockerfile"
  local image="nvim-test-${name}"
  local base_digest
  base_digest=$(resolve_base_digest "$dockerfile")
  logf "Building $image"
  docker build \
    --build-arg "BASE_IMAGE=$base_digest" \
    --build-arg "UID=$(id -u)" \
    --build-arg "GID=$(id -g)" \
    -t "$image" \
    -f "$dockerfile" \
    "$INFRA_DIR"
}

# --- parse flags ------------------------------------------------------------

BOOT=false
CHECK=false
BYPASS=false
SPEED=""
TIMEOUT=""
ACTION="" # build, pull, clear-cache, or empty (interactive)

# Expand combined short flags: -bs20 → -b -s20, -bx → -b -x
expanded=()
for arg in "$@"; do
  if [[ "$arg" =~ ^-[bcxhs]{2,} ]] || [[ "$arg" =~ ^-[bcxh]+s[0-9]+ ]]; then
    chars="${arg#-}"
    while [[ -n "$chars" ]]; do
      c="${chars:0:1}"
      chars="${chars:1}"
      if [[ "$c" == "s" && -n "$chars" ]]; then
        expanded+=("-s$chars")
        break
      fi
      expanded+=("-$c")
    done
  else
    expanded+=("$arg")
  fi
done
set -- "${expanded[@]+${expanded[@]}}"

args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
  -h | --help)
    usage
    exit 0
    ;;
  -b | --boot) BOOT=true ;;
  -c | --check) CHECK=true ;;
  -x | --bypass) BYPASS=true ;;
  -t | --timeout)
    TIMEOUT="${2:?--timeout requires a number}"
    shift
    ;;
  -s | --speed)
    SPEED="${2:?--speed requires a number}"
    shift
    ;;
  -s[0-9]*) SPEED="${1#-s}" ;;
  --build) ACTION=build ;;
  --pull) ACTION=pull ;;
  --clear-cache) ACTION=clear-cache ;;
  *) args+=("$1") ;;
  esac
  shift
done
set -- "${args[@]+${args[@]}}"

# --- action: clear-cache ----------------------------------------------------

if [[ "$ACTION" == "clear-cache" ]]; then
  if [[ -d "$PROXY_DIR/cache" ]]; then
    rm -rf "$PROXY_DIR/cache"
    logf "Proxy cache cleared"
  else
    logf "No proxy cache to clear"
  fi
  exit 0
fi

# --- action: pull ------------------------------------------------------------

if [[ "$ACTION" == "pull" ]]; then
  sed -n 's/^ARG BASE_IMAGE=\(.*\)/\1/p' "$INFRA_DIR"/*.Dockerfile | sort -u |
    while read -r base; do
      logf "Pulling $base"
      docker pull "$base"
    done
  exit 0
fi

# --- action: build -----------------------------------------------------------

if [[ "$ACTION" == "build" ]]; then
  for df in "$INFRA_DIR"/*.Dockerfile; do
    name=$(basename "$df" .Dockerfile)
    build_image "$name"
  done
  exit 0
fi

# --- proxy lifecycle --------------------------------------------------------

start_proxy() {
  # Generate CA cert if missing — mitmproxy creates it on first run
  if [[ ! -f "$PROXY_DIR/ca/mitmproxy-ca-cert.pem" ]]; then
    logf "Generating proxy CA certificate"
    mkdir -p "$PROXY_DIR/ca"
    docker run --rm -v "$PROXY_DIR/ca:/root/.mitmproxy" \
      mitmproxy/mitmproxy mitmdump --version >/dev/null
  fi

  # Reuse running container if speed setting matches
  local running
  running=$(docker inspect --format='{{.State.Running}}' nvim-test-proxy 2>/dev/null || true)
  if [[ "$running" == "true" ]]; then
    local cur_speed
    cur_speed=$(docker inspect --format='{{range .Config.Env}}{{println .}}{{end}}' nvim-test-proxy |
      sed -n 's/^PROXY_SPEED=//p')
    if [[ "${cur_speed:-1}" == "${SPEED:-1}" ]]; then
      logf "Proxy container already running"
      return
    fi
    logf "Restarting proxy (speed changed: ${cur_speed:-1} -> ${SPEED:-1})"
  fi

  # Build proxy image (cached by Docker after first build)
  logf "Building proxy image"
  docker build -t nvim-test-proxy -f "$PROXY_DIR/Dockerfile" "$PROXY_DIR" >/dev/null

  # Remove stopped container if it exists
  docker rm -f nvim-test-proxy &>/dev/null || true
  logf "Starting proxy container"
  mkdir -p "$PROXY_DIR/cache"
  docker run -d --name nvim-test-proxy \
    -p "$PROXY_PORT":8080 \
    -v "$PROXY_DIR/ca:/root/.mitmproxy" \
    -v "$PROXY_DIR/cache:/cache" \
    ${SPEED:+-e "PROXY_SPEED=$SPEED"} \
    nvim-test-proxy >/dev/null

  # Wait for proxy to be ready
  local retries=20
  while ! curl -sf -o /dev/null -x "http://localhost:$PROXY_PORT" http://mitm.it/cert/pem 2>/dev/null; do
    retries=$((retries - 1))
    if [[ $retries -le 0 ]]; then
      logf "ERROR: proxy failed to start"
      exit 1
    fi
    sleep 0.5
  done
}

# --- interactive: fzf-select one distro, build & run -----------------------

dockerfiles=$(find "$INFRA_DIR" -name '*.Dockerfile' -exec basename {} .Dockerfile \; | sort)
filter="${1:-}"

# Auto-select if filter matches exactly one distro
if [[ -n "$filter" ]]; then
  matches=$(printf '%s\n' "$dockerfiles" | grep -i "$filter" || true)
  count=$(printf '%s\n' "$matches" | grep -c . || true)
  if [[ "$count" -eq 1 ]]; then
    selection="$matches"
  else
    selection=$(printf '%s\n' "$dockerfiles" | fzf --query="$filter" --prompt="Select distro> " --height=~10) || exit 0
  fi
else
  selection=$(printf '%s\n' "$dockerfiles" | fzf --prompt="Select distro> " --height=~10) || exit 0
fi

build_image "$selection"

gh_token=$(gh auth token 2>/dev/null || true)

# Start proxy unless --bypass
if ! "$BYPASS"; then
  start_proxy
fi

container_name="nvim-test-run-${selection}"
docker rm -f "$container_name" 2>/dev/null || true

logf "Running nvim-test-${selection} (project mounted at ~/work)"

run_args=(
  docker run --rm -i
)
if ! "$CHECK"; then run_args+=(-t); fi
run_args+=(
  --name "$container_name"
  -v "$PROJECT_DIR:/home/testuser/work:ro"
  -e "NVIM_BOOTSTRAP_TIMEOUT=30000"
  ${gh_token:+-e "GITHUB_TOKEN=$gh_token"}
)

# Mount proxy CA and env script when proxy is active
if ! "$BYPASS"; then
  run_args+=(
    -v "$PROXY_DIR/ca/mitmproxy-ca-cert.pem:/tmp/proxy-ca.pem:ro"
    -v "$INFRA_DIR/proxy-env.sh:/tmp/proxy-env.sh:ro"
    -e "PROXY_PORT=$PROXY_PORT"
  )
fi

run_args+=("nvim-test-${selection}")

# shellcheck disable=SC2016 # $HOME expands inside the container, not on the host
# We cannot rely on exec bash -lc because Ubuntu's default .bashrc has an
# early-exit guard ("case $- in *i*) ;; *) return ;; esac") that skips the
# rest of the file — including the PATH/mise lines appended by install.sh —
# when the shell is non-interactive. Prepending the shim path inline avoids
# the guard entirely and matches what activate_mise() does for the install
# script itself.
MISE_PATH='PATH=$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH'

run_with_timeout() {
  if [[ -n "${TIMEOUT:-}" ]]; then
    timeout --signal=KILL "$TIMEOUT" "$@"
    local rc=$?
    if [[ $rc -eq 137 ]]; then
      logf "ERROR: container killed after ${TIMEOUT}s timeout"
      return 1
    fi
    return $rc
  else
    "$@"
  fi
}

if "$BOOT" && "$CHECK"; then
  # Default timeout for check mode
  : "${TIMEOUT:=120}"
  # shellcheck disable=SC2016
  run_with_timeout "${run_args[@]}" bash -lc \
    '$HOME/work/scripts/install.sh -y && exec bash -lc "'"$MISE_PATH"' nvim --headless -c \"luafile \$HOME/work/tests/infra/check.lua\" \$HOME/.bashrc"'
elif "$BOOT"; then
  # shellcheck disable=SC2016
  "${run_args[@]}" bash -lc \
    '$HOME/work/scripts/install.sh -y && exec bash -lc "'"$MISE_PATH"' nvim .bashrc; exec bash -l"'
else
  "${run_args[@]}" bash -l
fi
