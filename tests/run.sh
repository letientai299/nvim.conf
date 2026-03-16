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
#   ./tests/run.sh -h             # show this help
set -euo pipefail

# --- constants & helpers ----------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INFRA_DIR="$SCRIPT_DIR/infra"
PROXY_DIR="$SCRIPT_DIR/proxy"
PROXY_PORT="${PROXY_PORT:-8090}"

log() { printf '\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }

usage() {
  cat <<'EOF'
Usage: ./tests/run.sh [flags] [filter]

Flags:
  -b, --boot         Build, run, install, source bashrc, open nvim
  -x, --exec CMD     With -b: run CMD instead of "nvim .bashrc" (e.g., -x "nvim .")
      --bypass       Skip proxy, direct network access
  -s, --speed N      Replay cached responses N times faster (e.g., -s 4)
      --build        Build all test images (no interactive run)
      --pull         Pull latest base images
      --clear-cache  Wipe proxy cache directory
  -h, --help         Show this help

Arguments:
  filter             Substring to match distro name (auto-selects if unique)
EOF
}

# --- flag parsing -----------------------------------------------------------

BOOT=false
BYPASS=false
EXEC_CMD=""
SPEED=""
ACTION="" # build, pull, clear-cache, or empty (interactive)

# Expand combined short flags: -bs20 -> -b -s20
expand_combined_flags() {
  local expanded=()
  local arg chars c
  for arg in "$@"; do
    if [[ "$arg" =~ ^-[bhs]{2,} ]] || [[ "$arg" =~ ^-[bh]+s[0-9]+ ]]; then
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
  printf '%s\n' "${expanded[@]}"
}

parse_flags() {
  local args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    -b | --boot) BOOT=true ;;
    -x | --exec)
      EXEC_CMD="${2:?--exec requires a command}"
      shift
      ;;
    --bypass) BYPASS=true ;;
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
  POSITIONAL=("$@")
}

# --- actions ----------------------------------------------------------------

action_clear_cache() {
  if [[ -d "$PROXY_DIR/cache" ]]; then
    rm -rf "$PROXY_DIR/cache"
    log "Proxy cache cleared"
  else
    log "No proxy cache to clear"
  fi
}

action_pull() {
  sed -n 's/^ARG BASE_IMAGE=\(.*\)/\1/p' "$INFRA_DIR"/*.Dockerfile | sort -u |
    while read -r base; do
      log "Pulling $base"
      docker pull "$base"
    done
}

action_build() {
  local name
  for df in "$INFRA_DIR"/*.Dockerfile; do
    name="${df##*/}"
    name="${name%.Dockerfile}"
    build_image "$name"
  done
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
  log "Building $image"
  docker build \
    --build-arg "BASE_IMAGE=$base_digest" \
    --build-arg "UID=$(id -u)" \
    --build-arg "GID=$(id -g)" \
    -t "$image" \
    -f "$dockerfile" \
    "$INFRA_DIR"
}

# --- proxy ------------------------------------------------------------------

ensure_proxy_ca() {
  [[ -f "$PROXY_DIR/ca/mitmproxy-ca-cert.pem" ]] && return
  log "Generating proxy CA certificate"
  mkdir -p "$PROXY_DIR/ca"
  docker run --rm -v "$PROXY_DIR/ca:/root/.mitmproxy" \
    mitmproxy/mitmproxy mitmdump --version >/dev/null
}

build_proxy_image() {
  log "Building proxy image"
  docker build -t nvim-test-proxy -f "$PROXY_DIR/Dockerfile" "$PROXY_DIR" >/dev/null
}

run_proxy_container() {
  docker rm -f nvim-test-proxy &>/dev/null || true
  log "Starting proxy container"
  mkdir -p "$PROXY_DIR/cache"
  local run_args=(
    docker run -d --name nvim-test-proxy
    -p "$PROXY_PORT":8080
    -v "$PROXY_DIR/ca:/root/.mitmproxy"
    -v "$PROXY_DIR/cache:/cache"
  )
  if [[ -n "${SPEED:-}" ]]; then
    run_args+=(-e "PROXY_SPEED=$SPEED")
  fi
  run_args+=(nvim-test-proxy)
  "${run_args[@]}" >/dev/null
}

wait_for_proxy() {
  local retries=20
  while ! curl -sf -o /dev/null -x "http://localhost:$PROXY_PORT" http://mitm.it/cert/pem 2>/dev/null; do
    retries=$((retries - 1))
    if [[ $retries -le 0 ]]; then
      log "ERROR: proxy failed to start"
      exit 1
    fi
    sleep 0.5
  done
}

start_proxy() {
  ensure_proxy_ca

  # Reuse running container if speed setting matches
  local running
  running=$(docker inspect --format='{{.State.Running}}' nvim-test-proxy 2>/dev/null || true)
  if [[ "$running" == "true" ]]; then
    local cur_speed
    cur_speed=$(docker inspect --format='{{range .Config.Env}}{{println .}}{{end}}' nvim-test-proxy |
      sed -n 's/^PROXY_SPEED=//p')
    if [[ "${cur_speed:-1}" == "${SPEED:-1}" ]]; then
      log "Proxy container already running"
      return
    fi
    log "Restarting proxy (speed changed: ${cur_speed:-1} -> ${SPEED:-1})"
  fi

  build_proxy_image
  run_proxy_container
  wait_for_proxy
}

# --- distro selection -------------------------------------------------------

select_distro() {
  local filter="${1:-}"
  local distros=()
  local name
  for df in "$INFRA_DIR"/*.Dockerfile; do
    name="${df##*/}"
    name="${name%.Dockerfile}"
    distros+=("$name")
  done

  if [[ -n "$filter" ]]; then
    local matches count
    matches=$(printf '%s\n' "${distros[@]}" | grep -i "$filter" || true)
    count=$(printf '%s\n' "$matches" | grep -c . || true)
    if [[ "$count" -eq 1 ]]; then
      printf '%s' "$matches"
      return
    fi
    printf '%s\n' "${distros[@]}" | fzf --query="$filter" --prompt="Select distro> " --height=~10
  else
    printf '%s\n' "${distros[@]}" | fzf --prompt="Select distro> " --height=~10
  fi
}

# --- container execution ----------------------------------------------------

build_run_args() {
  local selection=$1
  local container_name="nvim-test-run-${selection}"
  local gh_token
  gh_token=$(gh auth token 2>/dev/null || true)

  docker rm -f "$container_name" 2>/dev/null || true

  RUN_ARGS=(docker run --rm -it
    --name "$container_name"
    -v "$PROJECT_DIR:/home/testuser/work:ro"
    -e "NVIM_BOOTSTRAP_TIMEOUT=30000"
  )
  if [[ -n "$gh_token" ]]; then
    RUN_ARGS+=(-e "GITHUB_TOKEN=$gh_token")
  fi

  # Mount proxy CA and env script when proxy is active
  if ! "$BYPASS"; then
    RUN_ARGS+=(
      -v "$PROXY_DIR/ca/mitmproxy-ca-cert.pem:/tmp/proxy-ca.pem:ro"
      -v "$INFRA_DIR/proxy-env.sh:/tmp/proxy-env.sh:ro"
      -e "PROXY_PORT=$PROXY_PORT"
    )
  fi

  RUN_IMAGE="nvim-test-${selection}"
}

# Generate a mounted entrypoint script that sets up the container environment.
# This replaces triple-nested quoting with a readable heredoc.
make_entrypoint() {
  local tmp
  tmp=$(mktemp "${TMPDIR:-/tmp}/nvim-test-entry.XXXXXX")
  cat >"$tmp" <<'ENTRY'
#!/usr/bin/env bash
set -euo pipefail
[ -f /tmp/proxy-env.sh ] && . /tmp/proxy-env.sh
"$HOME/work/scripts/install.sh" -y
"$HOME/.local/bin/mise" trust "$HOME/work"
PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"
exec "$@"
ENTRY
  chmod +x "$tmp"
  printf '%s' "$tmp"
}

run_container() {
  local selection=$1
  local entrypoint=""

  build_run_args "$selection"
  log "Running nvim-test-${selection} (project mounted at ~/work)"

  if "$BOOT"; then
    entrypoint=$(make_entrypoint)
    # shellcheck disable=SC2064
    trap "rm -f '$entrypoint'" EXIT
    RUN_ARGS+=(-v "$entrypoint:/tmp/entry.sh:ro")
    local boot_cmd="${EXEC_CMD:-nvim .bashrc}"
    "${RUN_ARGS[@]}" "$RUN_IMAGE" /tmp/entry.sh bash -c "$boot_cmd; exec bash -l"
  else
    "${RUN_ARGS[@]}" "$RUN_IMAGE" bash -l
  fi
}

# --- main -------------------------------------------------------------------

main() {
  local expanded
  mapfile -t expanded < <(expand_combined_flags "$@")
  parse_flags "${expanded[@]+${expanded[@]}}"

  case "$ACTION" in
  clear-cache)
    action_clear_cache
    return
    ;;
  pull)
    action_pull
    return
    ;;
  build)
    action_build
    return
    ;;
  esac

  local selection
  selection=$(select_distro "${POSITIONAL[0]:-}") || exit 0
  build_image "$selection"

  if ! "$BYPASS"; then
    start_proxy
  fi

  run_container "$selection"
}

main "$@"
