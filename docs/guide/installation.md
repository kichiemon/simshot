# Installation

simshot ships a prebuilt single binary for **macOS arm64 and x86_64** on every release. Pick whichever path fits your environment — all eight install the same `simshot` CLI.

## 1. Install script (curl)

Detects your architecture, downloads the matching prebuilt binary, verifies its sha256, and installs it to `/usr/local/bin` (or `~/.local/bin`):

```bash
curl -fsSL https://raw.githubusercontent.com/kichiemon/simshot/main/install.sh | bash
```

Customize with environment variables:

```bash
SIMSHOT_VERSION=v0.1.1                      # release tag (default: latest)
SIMSHOT_INSTALL_DIR=~/.local/bin            # install dir (default: auto)
```

## 2. Single binary (curl)

Grab the prebuilt binary directly from GitHub Releases — no Swift toolchain required:

```bash
# Apple Silicon (arm64)
curl -sL https://github.com/kichiemon/simshot/releases/download/v0.1.1/simshot-macos-arm64 -o /usr/local/bin/simshot && chmod +x /usr/local/bin/simshot

# Intel (x86_64)
curl -sL https://github.com/kichiemon/simshot/releases/download/v0.1.1/simshot-macos-x86_64 -o /usr/local/bin/simshot && chmod +x /usr/local/bin/simshot
```

## 3. Homebrew (tap)

```bash
brew tap kichiemon/homebrew-tap
brew install simshot
```

## 4. Nix

The repo ships a [`flake.nix`](https://github.com/kichiemon/simshot/blob/main/flake.nix) that fetches the prebuilt single binary (no source build):

```bash
nix run github:kichiemon/simshot              # run without installing
nix profile install github:kichiemon/simshot  # install into your profile
```

## 5. mise

The **github backend** is recommended — it also verifies SLSA provenance / artifact attestations:

```bash
mise use -g github:kichiemon/simshot
simshot --version
```

The legacy `ubi` backend (`mise use ubi:kichiemon/simshot`) also works but is deprecated in mise 2027.1.0.

## 6. npm

```bash
npm i -g simshot
npx simshot shoot
```

Requires Node.js 14+ on macOS. `postinstall` downloads the matching prebuilt single binary and verifies its sha256. The package is published on npm as `simshot`.

## 7. Mint

[Mint](https://github.com/yonaskolb/Mint) builds and installs from source via the [`Mintfile`](https://github.com/kichiemon/simshot/blob/main/Mintfile) (requires Xcode):

```bash
brew install mint
mint install kichiemon/simshot
```

## 8. Build from source

```bash
git clone https://github.com/kichiemon/simshot.git
cd simshot
swift build -c release
ln -s "$(pwd)/.build/release/simshot" /usr/local/bin/simshot
```

## Agent skill (bonus)

```bash
npx skills add kichiemon/simshot
```

Installs simshot as a reusable skill for Claude Code, opencode, and other skill-aware agents. For OpenAI Codex use `npx skills add kichiemon/simshot -a codex`. See [AI Agents](./ai-agents).
