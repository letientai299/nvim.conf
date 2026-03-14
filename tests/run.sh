#!/usr/bin/env bash
# Select a test Dockerfile via fzf, build, and run with the project mounted.
# Usage:
#   ./tests/run.sh              # fzf-select one distro, build & run
#   ./tests/run.sh ub           # pre-filter fzf with "ub", auto-pick if one match
#   ./tests/run.sh --build      # build all images (no interactive run)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INFRA_DIR="$SCRIPT_DIR/infra"

build_image() {
  local name=$1
  local dockerfile="$INFRA_DIR/${name}.Dockerfile"
  local image="nvim-test-${name}"
  echo "==> Building $image"
  docker build \
    --build-arg "UID=$(id -u)" \
    --build-arg "GID=$(id -g)" \
    -t "$image" \
    -f "$dockerfile" \
    "$INFRA_DIR"
}

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

echo "==> Running nvim-test-${selection} (project mounted at ~/work)"
docker run --rm -it \
  -v "$PROJECT_DIR:/home/testuser/work:ro" \
  ${gh_token:+-e "GITHUB_TOKEN=$gh_token"} \
  "nvim-test-${selection}" \
  bash -l
