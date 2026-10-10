#!/usr/bin/env bash
#
# simshot installer — downloads the prebuilt macOS single binary from GitHub
# Releases, verifies its sha256, and installs it into your PATH.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/kichiemon/simshot/main/install.sh | bash
#
# Environment:
#   SIMSHOT_VERSION        Release tag to install (default: latest, e.g. v0.2.1)
#   SIMSHOT_INSTALL_DIR    Install directory (default: /usr/local/bin if
#                          writable, otherwise ~/.local/bin)
#
set -euo pipefail

REPO="kichiemon/simshot"
VERSION="${SIMSHOT_VERSION:-latest}"
INSTALL_DIR="${SIMSHOT_INSTALL_DIR:-}"

fail() {
  echo "error: $*" >&2
  exit 1
}

# Platform: simshot only ships macOS binaries.
case "$(uname -s)" in
  Darwin) ;;
  *) fail "simshot only ships macOS binaries (found $(uname -s)). Install with Homebrew or build from source instead." ;;
esac

# Architecture: map to the release asset suffix.
case "$(uname -m)" in
  arm64 | aarch64) ARCH="arm64" ;;
  x86_64 | amd64) ARCH="x86_64" ;;
  *) fail "unsupported architecture: $(uname -m)." ;;
esac

# Resolve the release tag (latest via the GitHub API, or an explicit tag).
if [ "$VERSION" = "latest" ]; then
  VERSION="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)"
  [ -n "$VERSION" ] || fail "could not resolve the latest release tag from GitHub."
fi

ASSET="simshot-macos-${ARCH}"
BASE_URL="https://github.com/${REPO}/releases/download/${VERSION}"
BIN_URL="${BASE_URL}/${ASSET}"
SHA_URL="${BIN_URL}.sha256"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/simshot-install.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

echo "> Downloading ${ASSET} ${VERSION}..."
curl -fsSL "$BIN_URL" -o "$tmp/simshot"
curl -fsSL "$SHA_URL" -o "$tmp/simshot.sha256"

# Verify the checksum before installing.
expected="$(awk '{print $1}' "$tmp/simshot.sha256")"
actual="$(shasum -a 256 "$tmp/simshot" | awk '{print $1}')"
[ "$expected" = "$actual" ] || fail "sha256 mismatch for ${ASSET}: expected ${expected}, got ${actual}. Refusing to install a tampered binary."
echo "> Verified sha256 ${actual}"

chmod +x "$tmp/simshot"

# Pick the install directory.
if [ -z "$INSTALL_DIR" ]; then
  if [ -w /usr/local/bin ]; then
    INSTALL_DIR=/usr/local/bin
  else
    INSTALL_DIR="${HOME}/.local/bin"
  fi
fi

mkdir -p "$INSTALL_DIR"
install -m 755 "$tmp/simshot" "$INSTALL_DIR/simshot"

echo "> Installed simshot ${VERSION} (${ARCH}) to ${INSTALL_DIR}/simshot"
echo "> Run ${INSTALL_DIR}/simshot --version to verify."

# Tell the user to add the directory to PATH if it is not already there.
case ":$PATH:" in
  *":${INSTALL_DIR}:"*) ;;
  *) echo "> ${INSTALL_DIR} is not on your PATH. Add it with: export PATH=\"${INSTALL_DIR}:\$PATH\"" ;;
esac
