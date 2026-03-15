#!/bin/sh
# Bootstrap script for nvim.conf — installs mise, neovim, shared CLI tools, and
# bootstraps startup-triggered plugins on a bare machine. Requires sh + curl
# (or wget) + git.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/letientai299/nvim.conf/main/scripts/install.sh | sh
#   ./scripts/install.sh                            # from a local clone
#   ./scripts/install.sh -y                         # unattended / CI
#
# Local development:
#   When run from a local clone, the script offers to symlink ~/.config/nvim
#   to the repo instead of cloning. This is useful for contributors and for
#   testing inside Docker containers (see tests/run.sh). The container mounts
#   the repo read-only at ~/work; the symlink lets nvim find the config while
#   host edits are immediately visible without restarting the container.
#   Read-only mounts are handled gracefully: git index updates are skipped,
#   and init.lua redirects lazy-lock.json to a writable path automatically.
set -eu

REPO_URL="https://github.com/letientai299/nvim.conf"
NVIM_CONFIG="${HOME}/.config/nvim"
MISE_SHIMS="${HOME}/.local/share/mise/shims"

# Detect if we're running from a local repo checkout
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCAL_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- helpers ----------------------------------------------------------------

log() { printf '==> %s\n' "$*"; }
die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$1"
  else
    die "Neither curl nor wget found. Install one and re-run."
  fi
}

AUTO_YES=false
for arg in "$@"; do
  case "$arg" in
  -y | --yes) AUTO_YES=true ;;
  esac
done

# Returns true when prompts should be shown (interactive tty, no -y flag)
should_prompt() { [ "$AUTO_YES" = false ] && [ -t 0 ]; }

# --- 1. Install mise --------------------------------------------------------

install_mise() {
  if command -v mise >/dev/null 2>&1 || [ -x "${HOME}/.local/bin/mise" ]; then
    log "mise already installed"
    return
  fi
  log "Installing mise..."
  fetch https://mise.jdx.dev/install.sh | sh
}

# --- 2. Activate mise in shell rc -------------------------------------------

activate_mise() {
  # Ensure rc files exist (bare containers may have none)
  if [ ! -f "${HOME}/.bashrc" ] && [ ! -f "${HOME}/.zshrc" ]; then
    touch "${HOME}/.bashrc"
  fi

  for rc in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
    [ -f "$rc" ] || continue
    case "$rc" in
    *bashrc) shell=bash ;;
    *zshrc) shell=zsh ;;
    esac

    # PATH for mise binary and shims — must come before mise activate
    if ! grep -q '\.local/bin' "$rc" 2>/dev/null; then
      # shellcheck disable=SC2016
      printf '\nexport PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"\n' >>"$rc"
    fi

    if ! grep -q 'mise activate' "$rc" 2>/dev/null; then
      log "Adding mise activate to $rc"
      # shellcheck disable=SC2016
      printf 'eval "$(mise activate %s)"\n' "$shell" >>"$rc"
    fi
  done

  # Ensure .bash_profile sources .bashrc (many containers skip it)
  if [ -f "${HOME}/.bashrc" ]; then
    if [ ! -f "${HOME}/.bash_profile" ]; then
      printf '[ -f ~/.bashrc ] && . ~/.bashrc\n' >"${HOME}/.bash_profile"
    elif ! grep -q '\.bashrc' "${HOME}/.bash_profile" 2>/dev/null; then
      printf '\n[ -f ~/.bashrc ] && . ~/.bashrc\n' >>"${HOME}/.bash_profile"
    fi
  fi

  # Make tools available for the remaining steps in this script
  export PATH="${HOME}/.local/bin:${MISE_SHIMS}:${PATH}"
  if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate sh 2>/dev/null)" || true
  fi
}

# --- 3. Install neovim via mise if missing -----------------------------------

install_neovim() {
  if command -v nvim >/dev/null 2>&1; then
    log "neovim already installed"
    return
  fi
  log "Installing neovim via mise..."
  mise use -g neovim
}

# --- 4. Install global CLI tools --------------------------------------------

install_cli_tools() {
  missing=""
  for pair in "fzf:fzf" "fd:fd" "ripgrep:rg" "tree-sitter:tree-sitter"; do
    pkg="${pair%%:*}"
    bin="${pair#*:}"
    if ! command -v "$bin" >/dev/null 2>&1; then
      missing="$missing $pkg"
    fi
  done
  if [ -z "$missing" ]; then
    log "Global CLI tools already installed"
    return
  fi
  log "Installing global CLI tools:$missing"
  # shellcheck disable=SC2086
  mise use -g $missing
}

# --- 5. Handle ~/.config/nvim -----------------------------------------------

# True when the script lives inside a local repo clone (has init.lua at root)
is_local_repo() { [ -f "$LOCAL_REPO/init.lua" ]; }

install_config_fresh() {
  mkdir -p "$(dirname "$NVIM_CONFIG")"
  if is_local_repo; then
    if should_prompt; then
      printf 'Symlink %s to local repo %s? [Y/n] ' "$NVIM_CONFIG" "$LOCAL_REPO"
      read -r answer
      case "$answer" in
      [Nn]*)
        log "Cloning config to $NVIM_CONFIG"
        git clone "$REPO_URL" "$NVIM_CONFIG"
        return
        ;;
      esac
    fi
    ln -s "$LOCAL_REPO" "$NVIM_CONFIG"
    log "Config symlinked: $NVIM_CONFIG -> $LOCAL_REPO"
  else
    log "Cloning config to $NVIM_CONFIG"
    git clone "$REPO_URL" "$NVIM_CONFIG"
  fi
}

setup_config() {
  if [ ! -e "$NVIM_CONFIG" ]; then
    install_config_fresh
    return
  fi

  # Already symlinked to the local repo — nothing to do
  if [ -L "$NVIM_CONFIG" ] && [ "$(readlink "$NVIM_CONFIG")" = "$LOCAL_REPO" ]; then
    log "Config already symlinked to $LOCAL_REPO"
    return
  fi

  # Config dir exists — check if it's the right repo
  if [ -d "$NVIM_CONFIG/.git" ]; then
    remote=$(git -C "$NVIM_CONFIG" remote get-url origin 2>/dev/null || echo "")
    case "$remote" in
    *letientai299/nvim.conf*)
      if git -C "$NVIM_CONFIG" diff --quiet 2>/dev/null; then
        log "Config clean — pulling latest..."
        git -C "$NVIM_CONFIG" pull --ff-only || log "WARNING: git pull failed. Run manually."
      else
        log "WARNING: $NVIM_CONFIG has uncommitted changes. Run 'git pull' manually."
      fi
      return
      ;;
    esac
  fi

  # Wrong repo or not a git repo — back up and clone
  backup="${NVIM_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
  if should_prompt; then
    printf 'Back up %s to %s and clone fresh? [Y/n] ' "$NVIM_CONFIG" "$backup"
    read -r answer
    case "$answer" in
    [Nn]*)
      log "Skipping config setup."
      return
      ;;
    esac
  else
    log "Backing up $NVIM_CONFIG to $backup"
  fi

  mv "$NVIM_CONFIG" "$backup"
  log "Previous config backed up to $backup"
  install_config_fresh
}

# --- 6. Optionally ignore lazy-lock.json changes --------------------------
#
# On-demand plugin installs rewrite lazy-lock.json. In writable clones this
# makes the working tree dirty and blocks subsequent git pull. Using
# --assume-unchanged hides local changes from git status / diff while still
# allowing upstream changes to overwrite the file on pull.
#
# On read-only mounts (e.g., tests/run.sh containers), git update-index
# fails harmlessly. init.lua separately handles this by redirecting the
# lockfile to ~/.cache/nvim/ when the config dir isn't writable.

configure_lockfile() {
  lockfile="$NVIM_CONFIG/lazy-lock.json"
  [ -f "$lockfile" ] || return

  # Already ignored — nothing to do
  if git -C "$NVIM_CONFIG" ls-files -v lazy-lock.json 2>/dev/null | grep -q '^h '; then
    return
  fi

  if should_prompt; then
    printf 'Ignore lazy-lock.json changes in git? [Y/n] '
    read -r answer
    case "$answer" in
    [Nn]*) return ;;
    esac
  fi

  if git -C "$NVIM_CONFIG" update-index --assume-unchanged lazy-lock.json 2>/dev/null; then
    log "lazy-lock.json changes hidden from git (assume-unchanged)"
  else
    log "WARNING: could not update git index (read-only filesystem?). Skipping."
  fi
}

# --- 7. Bootstrap plugins --------------------------------------------------
#
# Simulates an interactive startup in headless mode so on-demand installs
# trigger for plugins that would load in a normal session. No plugin list
# to maintain — lib/bootstrap.lua fires UIEnter (which triggers VeryLazy),
# waits for all async clones to finish, then quits.
#
# Default theme (catppuccin-mocha) is configured in init.lua and applies
# when no store-theme state file exists yet.

bootstrap_plugins() {
  log "Bootstrapping plugins (headless)..."
  nvim --headless +"lua require('lib.bootstrap').run()"
}

# --- 8. Ensure shims exist for all installed tools -------------------------

refresh_shims() {
  if command -v mise >/dev/null 2>&1; then
    mise reshim
  fi
}

# --- main -------------------------------------------------------------------

install_mise
activate_mise
install_neovim
install_cli_tools
refresh_shims
setup_config
configure_lockfile
bootstrap_plugins

log "Done. Restart your shell or run: source ~/.bashrc"
