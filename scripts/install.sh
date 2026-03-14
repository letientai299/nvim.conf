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

is_interactive() { [ -t 0 ]; }

# --- 1. Install mise --------------------------------------------------------

install_mise() {
  if command -v mise >/dev/null 2>&1; then
    log "mise already installed"
    return
  fi
  log "Installing mise..."
  fetch https://mise.jdx.dev/install.sh | sh
}

# --- 2. Activate mise in shell rc -------------------------------------------

activate_mise() {
  # Add mise activate + shims to the appropriate shell rc file.
  for rc in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
    [ -f "$rc" ] || continue
    case "$rc" in
    *bashrc) shell=bash ;;
    *zshrc) shell=zsh ;;
    esac
    if ! grep -q 'mise activate' "$rc" 2>/dev/null; then
      log "Adding mise activate to $rc"
      # shellcheck disable=SC2016
      printf '\n# mise\neval "$(mise activate %s)"\n' "$shell" >>"$rc"
    fi
    if ! grep -q 'mise/shims' "$rc" 2>/dev/null; then
      # shellcheck disable=SC2016
      printf 'export PATH="%s:$PATH"\n' "$MISE_SHIMS" >>"$rc"
    fi
  done

  # If no shell rc exists (e.g., bare container), create .bashrc
  if [ ! -f "${HOME}/.bashrc" ] && [ ! -f "${HOME}/.zshrc" ]; then
    log "Creating ~/.bashrc with mise activation"
    # shellcheck disable=SC2016
    printf '# mise\neval "$(mise activate bash)"\nexport PATH="%s:$PATH"\n' \
      "$MISE_SHIMS" >"${HOME}/.bashrc"
  fi

  # Source mise into the current shell for remaining steps
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

# --- 5. Install global CLI tools --------------------------------------------

install_cli_tools() {
  missing=""
  for pair in "fzf:fzf" "fd:fd" "ripgrep:rg" "bat:bat"; do
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

# --- 6. Handle ~/.config/nvim -----------------------------------------------

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
        log "Config already installed and clean"
      else
        log "WARNING: $NVIM_CONFIG has uncommitted changes. Run 'git pull' manually."
      fi
      return
      ;;
    esac
  fi

  # Wrong repo or not a git repo — back up and clone
  backup="${NVIM_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
  if is_interactive; then
    printf 'Back up %s to %s and clone fresh? [Y/n] ' "$NVIM_CONFIG" "$backup"
    read -r answer
    case "$answer" in
    [Nn]*)
      log "Skipping config setup."
      return
      ;;
    esac
  else
    log "Non-interactive: backing up $NVIM_CONFIG to $backup"
  fi

  mv "$NVIM_CONFIG" "$backup"
  git clone "$REPO_URL" "$NVIM_CONFIG"
  log "Config cloned. Previous config backed up to $backup"
}

# --- main -------------------------------------------------------------------

install_mise
activate_mise
install_neovim
install_cli_tools
setup_config

log "Done. Restart your shell or run: source ~/.bashrc"
