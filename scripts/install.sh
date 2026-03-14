#!/bin/sh
# Bootstrap script for nvim.conf — installs mise, neovim, and global CLI tools
# on a bare machine. Requires sh + curl (or wget) + git.
set -eu

REPO_URL="https://github.com/letientai299/nvim.conf"
NVIM_CONFIG="${HOME}/.config/nvim"
MISE_SHIMS="${HOME}/.local/share/mise/shims"

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
  for pair in "fzf:fzf" "fd:fd" "ripgrep:rg"; do
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

setup_config() {
  if [ ! -e "$NVIM_CONFIG" ]; then
    log "Cloning config to $NVIM_CONFIG"
    mkdir -p "$(dirname "$NVIM_CONFIG")"
    git clone "$REPO_URL" "$NVIM_CONFIG"
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
  git clone "$REPO_URL" "$NVIM_CONFIG"
  log "Config cloned. Previous config backed up to $backup"
}

# --- 6. Optionally ignore lazy-lock.json changes --------------------------
#
# On-demand plugin installs rewrite lazy-lock.json. In containers this makes
# the working tree dirty and blocks subsequent git pull. Using
# --assume-unchanged hides local changes from git status / diff while still
# allowing upstream changes to overwrite the file on pull (unless both sides
# changed, which is unlikely for a consumer-only checkout).

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

  git -C "$NVIM_CONFIG" update-index --assume-unchanged lazy-lock.json
  log "lazy-lock.json changes hidden from git (assume-unchanged)"
}

# --- 7. Bootstrap essential plugins ----------------------------------------
#
# Runs nvim headless to clone lazy.nvim + catppuccin so the first interactive
# session looks good immediately. Skips if catppuccin is already installed.
# The default theme (catppuccin-mocha) is configured in init.lua and applies
# when no themery state.json exists yet.

bootstrap_plugins() {
  lazy_dir="${HOME}/.local/share/nvim/lazy"
  if [ -d "$lazy_dir/catppuccin" ]; then
    log "Essential plugins already installed"
    return
  fi
  log "Installing essential plugins (headless)..."
  nvim --headless \
    +'lua require("lazy").install({ plugins = { "catppuccin" }, wait = true, show = false })' \
    +qa
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
