#!/usr/bin/env bash
# Download and install the Roslyn C# language server from
# github.com/Crashdummyy/roslynLanguageServer (repackaged official builds
# that support --stdio, used by the Mason registry and roslyn.nvim).
# Creates a wrapper in the mise shims directory.
set -euo pipefail

INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/roslyn-ls"
MISE_SHIMS="${MISE_SHIMS:-$HOME/.local/share/mise/shims}"
WRAPPER_DIR="${ROSLYN_WRAPPER_DIR:-$HOME/.local/bin}"
REPO="Crashdummyy/roslynLanguageServer"

# Keep the script aligned with the repo's main installer: make the mise binary
# path and shims visible before any command checks or installs.
export PATH="$HOME/.local/bin:$MISE_SHIMS:$PATH"

write_wrapper() {
  local dir="$1"
  mkdir -p "$dir"
  cat >"$dir/roslyn" <<EOF
#!/usr/bin/env bash
exec dotnet "$INSTALL_DIR/Microsoft.CodeAnalysis.LanguageServer.dll" "\$@"
EOF
  chmod +x "$dir/roslyn"
}

ensure_wrapper() {
  # Place wrapper in ~/.local/bin (always on PATH in our test harness) and
  # also in mise shims for environments that include that path.
  write_wrapper "$WRAPPER_DIR"
  write_wrapper "$MISE_SHIMS"
}

is_install_healthy() {
  [ -f "$INSTALL_DIR/Microsoft.CodeAnalysis.LanguageServer.dll" ]
}

# `dotnet` and `7zz` are installed via tool-installer before this script runs.
# `curl` remains a host requirement.
for tool in dotnet curl 7zz; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Error: $tool is required but not installed" >&2
    exit 1
  fi
done

# Detect platform asset name
case "$(uname -s)-$(uname -m)" in
Darwin-arm64) asset="microsoft.codeanalysis.languageserver.osx-arm64.zip" ;;
Darwin-x86_64) asset="microsoft.codeanalysis.languageserver.osx-x64.zip" ;;
Linux-aarch64) asset="microsoft.codeanalysis.languageserver.linux-arm64.zip" ;;
Linux-x86_64) asset="microsoft.codeanalysis.languageserver.linux-x64.zip" ;;
*)
  echo "Unsupported platform: $(uname -s)-$(uname -m)" >&2
  exit 1
  ;;
esac

# Resolve latest release tag via GitHub's redirect target.
latest_url=$(
  curl -fsSIL -o /dev/null -w '%{url_effective}' \
    "https://github.com/$REPO/releases/latest"
)
version="${latest_url##*/}"

if [ -z "$version" ] || [ "$version" = "null" ]; then
  echo "Failed to determine Roslyn LSP version" >&2
  exit 1
fi

# Skip if already installed at this version
if [ -f "$INSTALL_DIR/.version" ] && [ "$(cat "$INSTALL_DIR/.version")" = "$version" ]; then
  ensure_wrapper
  if is_install_healthy; then
    exit 0
  fi
  echo "Cached Roslyn version is incomplete; reinstalling..." >&2
fi

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

echo "Downloading Roslyn LSP v$version ($asset)..."
curl -fsSL -o "$tmp_dir/$asset" \
  "https://github.com/$REPO/releases/download/$version/$asset"

7zz x -y "-o$tmp_dir/extracted" "$tmp_dir/$asset" >/dev/null

dll=$(find "$tmp_dir/extracted" -name "Microsoft.CodeAnalysis.LanguageServer.dll" | head -1)
if [ -z "$dll" ]; then
  echo "DLL not found in package" >&2
  exit 1
fi

dll_dir=$(dirname "$dll")

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -R "$dll_dir"/* "$INSTALL_DIR/"
printf '%s' "$version" >"$INSTALL_DIR/.version"

# Wrapper script so vim.fn.executable("roslyn") resolves through mise's tool dir.
ensure_wrapper

if ! is_install_healthy; then
  echo "Roslyn install failed: missing language server DLL" >&2
  exit 1
fi

echo "Roslyn LSP v$version installed"
