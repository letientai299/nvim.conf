#!/usr/bin/env bash
# Select a test Dockerfile via fzf, build, and run with the project mounted.
# Usage:
#   ./tests/run.sh              # fzf-select one distro, build & run
#   ./tests/run.sh ub           # pre-filter fzf with "ub", auto-pick if one match
#   ./tests/run.sh --boot ub    # build, run, install, source, open nvim
#   ./tests/run.sh --build      # build all images (no interactive run)
#   ./tests/run.sh --pull       # pull latest base images, then rebuild all
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INFRA_DIR="$SCRIPT_DIR/infra"

logf() { printf '\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }

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

# --- --pull: pull latest base images ----------------------------------------

if [[ "${1:-}" == "--pull" ]]; then
  sed -n 's/^ARG BASE_IMAGE=\(.*\)/\1/p' "$INFRA_DIR"/*.Dockerfile | sort -u |
    while read -r base; do
      logf "Pulling $base"
      docker pull "$base"
    done
  exit 0
fi

# --- parse --boot flag anywhere in args ------------------------------------

BOOT=false
args=()
for arg in "$@"; do
  if [[ "$arg" == "--boot" ]]; then
    BOOT=true
  else
    args+=("$arg")
  fi
done
set -- "${args[@]+${args[@]}}"

# --- --build: build all images ---------------------------------------------

if [[ "${1:-}" == "--build" ]]; then
  for df in "$INFRA_DIR"/*.Dockerfile; do
    name=$(basename "$df" .Dockerfile)
    build_image "$name"
  done
  exit 0
fi

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

logf "Running nvim-test-${selection} (project mounted at ~/work)"

run_args=(
  docker run --rm -it
  -v "$PROJECT_DIR:/home/testuser/work:ro"
  ${gh_token:+-e "GITHUB_TOKEN=$gh_token"}
  "nvim-test-${selection}"
)

if "$BOOT"; then
  # shellcheck disable=SC2016 # $HOME expands inside the container, not on the host
  "${run_args[@]}" bash -lc \
    '$HOME/work/scripts/install.sh -y && source $HOME/.bashrc && nvim .bashrc; exec bash -l'
else
  "${run_args[@]}" bash -l
fi
