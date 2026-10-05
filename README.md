# simshot

**[English](README.md) · [日本語](README.ja.md) · [한국어](README.ko.md)**

![CI](https://img.shields.io/github/actions/workflow/status/kichiemon/simshot/ci.yml?style=flat-square&label=CI)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-F05138?style=flat-square&logo=swift&logoColor=white)
![License](https://img.shields.io/github/license/kichiemon/simshot?style=flat-square&color=blue)
![Stars](https://img.shields.io/github/stars/kichiemon/simshot?style=social)

Capture App Store-ready screenshots from the iOS Simulator with **`simctl` only — no XCUITest, no flaky test runners, no hangs.**

> ⭐ If simshot makes your next release easier, consider starring the repo. Questions or ideas? Join the [Discussions](https://github.com/kichiemon/simshot/discussions).

![simshot demo](assets/demo.gif)

Your app implements a tiny `#if DEBUG` launch-argument handler; simshot does the rest: build, boot simulators, override the status bar, launch each scene, capture, and resize to App Store sizes.

```bash
simshot shoot --project Kanapp.xcodeproj --scheme Kanapp \
  --bundle-id dev.kichiemon.kanapp \
  --devices iphone-17-pro-max,ipad-pro-13 \
  --langs ja,en --shots shots.json --resize
```

## Why simshot?

`fastlane snapshot` drives the UI through **XCUITest**, which means maintaining test targets, fighting flaky element queries, and dealing with runner crashes. simshot inverts the model: the **app itself** navigates to each scene (reading a documented launch-argument protocol), and simshot just drives `simctl` with a hard timeout on every step.

| | simshot | fastlane snapshot |
|---|---|---|
| UI automation | **None** — `simctl` only | XCUITest runner |
| Hangs | **Hard timeout on every command** | Can hang CI |
| Ruby | **No** | Ruby + fastlane + gems |
| Test target | `#if DEBUG` handler in your app | Dedicated UI test target |
| Status bar override | **Built in** | Plugin |
| Resize to App Store sizes | **Built in** (`--resize`) | Separate tooling |
| Multi-language | `--langs ja,en` | Per-locale setup |
| Dependency footprint | **Zero** | Dozens of gems |

## How it works

1. `xcodebuild` builds the app for the generic simulator (or use an existing `.app` with `--app-path`).
2. For each device × language:
   - `simctl bootstatus <udid> -b` boots (and waits).
   - `simctl status_bar <udid> override --time "9:41" --batteryState charged --batteryLevel 100 ...` prettifies the status bar.
   - The app is installed (previous install removed first for a clean state).
   - For each shot, simshot launches the app with the scene protocol args, waits for the scene to settle, then takes `simctl io <udid> screenshot`.
3. Raw captures land in `<output>/raw/<device>/<lang>/`, and (with `--resize`) App Store-ready copies — alpha flattened, resized to the matching size — in `<output>/<device>/<lang>/`.

Every external command runs through a **timeout + retry** wrapper, so a crashed app or stuck simulator can never hang CI.

## Install

Eight ways to get `simshot` — pick one:

| # | Path | Command | Needs |
|---|---|---|---|
| 1 | Install script (curl) | `curl -fsSL …/install.sh \| bash` | macOS |
| 2 | Homebrew (tap) | `brew tap kichiemon/homebrew-tap && brew install simshot` | Homebrew |
| 3 | Single binary (curl) | download `simshot-macos-{arm64,x86_64}` | macOS |
| 4 | Nix | `nix profile install github:kichiemon/simshot` | Nix |
| 5 | mise | `mise use -g github:kichiemon/simshot` | mise |
| 6 | npm | `npm i -g simshot` | Node.js 14+ |
| 7 | Mint | `mint install kichiemon/simshot` | Xcode |
| 8 | Build from source | `swift build -c release` | Xcode |
| + | Agent skill | `npx skills add kichiemon/simshot` | npx |

### Install script (curl, macOS)

One-liner that detects your architecture, downloads the matching prebuilt binary from GitHub Releases, verifies its sha256, and installs it to `/usr/local/bin` (or `~/.local/bin`):

```bash
curl -fsSL https://raw.githubusercontent.com/kichiemon/simshot/main/install.sh | bash
```

Customize with `SIMSHOT_VERSION` (release tag) and `SIMSHOT_INSTALL_DIR`:

```bash
SIMSHOT_VERSION=v0.2.0 SIMSHOT_INSTALL_DIR=~/.local/bin \
  curl -fsSL https://raw.githubusercontent.com/kichiemon/simshot/main/install.sh | bash
```

### Install as an agent skill (npx)

```bash
npx skills add kichiemon/simshot
```

Installs simshot as a reusable agent skill (for Claude Code / opencode and other skill-aware agents). Once installed, skill-aware agents can use simshot automatically — just ask it to capture App Store screenshots, and the agent builds and runs `simshot shoot` for you (see [`skills/simshot/SKILL.md`](skills/simshot/SKILL.md)).

Target a specific agent, for example **OpenAI Codex**:

```bash
npx skills add kichiemon/simshot -a codex
```

This installs the skill into `.agents/skills/` (Codex's project skill directory). The skill is kept in sync across three locations — `skills/simshot/SKILL.md` (canonical), `.claude/skills/simshot/SKILL.md` (Claude Code), and `.agents/skills/simshot/SKILL.md` (Codex and other `.agents/skills/` agents) — so all skill-aware agents get identical instructions.

### Build from source

```bash
git clone https://github.com/kichiemon/simshot.git
cd simshot
swift build -c release
# binary at .build/release/simshot — symlink or copy it into your PATH
ln -s "$(pwd)/.build/release/simshot" /usr/local/bin/simshot
```

### Single binary (curl, macOS)

Grab the prebuilt binary for your architecture directly from GitHub Releases — no Swift toolchain required:

```bash
# Apple Silicon (arm64)
curl -sL https://github.com/kichiemon/simshot/releases/download/v0.2.0/simshot-macos-arm64 -o /usr/local/bin/simshot && chmod +x /usr/local/bin/simshot

# Intel (x86_64)
curl -sL https://github.com/kichiemon/simshot/releases/download/v0.2.0/simshot-macos-x86_64 -o /usr/local/bin/simshot && chmod +x /usr/local/bin/simshot
```

### Nix

The repo ships a [`flake.nix`](flake.nix) that fetches the prebuilt single binary (no source build):

```bash
nix run github:kichiemon/simshot          # run without installing
nix profile install github:kichiemon/simshot   # install into your profile
```

### mise

[mise](https://mise.jdx.dev/) installs simshot from the GitHub Releases assets. The **github backend** is recommended (it also verifies SLSA provenance / artifact attestations):

```bash
mise use -g github:kichiemon/simshot   # install into your global config
simshot --version                      # v0.2.0
```

The legacy `ubi` backend (`mise use ubi:kichiemon/simshot`) resolves the same `simshot-macos-{os}-{arch}` release assets and also works, but it is deprecated in mise and will be removed in mise 2027.1.0.

### Homebrew (tap, recommended)

simshot ships a tap formula that installs the prebuilt release binary. First time:

```bash
brew tap kichiemon/homebrew-tap
brew install simshot
```

> Formula source: [`kichiemon/homebrew-tap`](https://github.com/kichiemon/homebrew-tap) (`Formula/simshot.rb`):

```ruby
class Simshot < Formula
  desc "App Store screenshot capture CLI (simctl only, no XCUITest)"
  homepage "https://github.com/kichiemon/simshot"
  version "0.2.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/kichiemon/simshot/releases/download/v0.2.0/simshot-macos-arm64.tar.gz"
      sha256 "317c91b67a3727285be0b6b282c57aece58b5e1d79d4959606c4e0508ae1e121"
    end
    on_intel do
      url "https://github.com/kichiemon/simshot/releases/download/v0.2.0/simshot-macos-x86_64.tar.gz"
      sha256 "0a570bc663fd4920a3b22506e20ab5ee28389bc643bbc99517c8688e46afd6e4"
    end
  end

  def install
    bin.install "simshot"
  end
end
```

### Mint

[Mint](https://github.com/yonaskolb/Mint) builds and installs simshot from source via the [`Mintfile`](Mintfile) (requires Xcode):

```bash
brew install mint
mint install kichiemon/simshot
```

### npm (npmjs.com)

```bash
npm i -g simshot
npx simshot shoot
```

Requires Node.js 14+ on macOS (arm64/x86_64). The package downloads the matching prebuilt single binary from GitHub Releases in `postinstall` (see [`npm/`](npm/)) and verifies its sha256. Published on npm as `simshot` — the registry still serves v0.1.1, which predates `simshot verify`.

## Quick start

1. Add the [scene protocol handler](#screenshot-scene-protocol) to your app (5 minutes).
2. Verify the environment and list simulators:

   ```bash
   simshot doctor     # diagnose xcode-select / Xcode / simctl / runtimes
   simshot devices    # list available simulators
   ```

3. Create a `shots.json` (see [`examples/shots.json`](examples/shots.json)) or use `--scenes`:

   ```bash
   simshot shoot --project MyApp.xcodeproj --scheme MyApp \
     --bundle-id com.example.myapp \
     --devices iphone-17-pro-max,ipad-pro-13 \
     --langs ja,en --scenes home,detail,settings \
     --output appstore --resize
   ```

Screenshots land in `appstore/<device>/<lang>/NN_name.png`.

## Commands

| Command | Description |
|---|---|
| `simshot shoot <options>` | Build, boot, capture, and resize screenshots. |
| `simshot devices` | List available simulators (name + UDID). |
| `simshot doctor` | Diagnose the local Xcode / simulator environment (exit 1 on problems). |
| `simshot init` | Generate a commented `simshot.yml` config scaffold. |
| `simshot verify [dir]` | Check captured screenshots against App Store requirements (exit 1 on problems). |
| `simshot version` | Print the version. |
| `simshot help` | Show help. |

### `simshot doctor`

Checks `xcode-select`, Xcode, `simctl`, iOS runtimes, and available simulators, and exits `1` if anything is broken. Run it when setting up a new machine or before filing a bug.

```text
$ simshot doctor
✅ xcode-select: /Applications/Xcode.app/Contents/Developer
✅ Xcode: Xcode 26.5
✅ simctl: found
✅ iOS runtimes: 7 installed
✅ Available simulators: 36 available

✅ All checks passed.
```

### `simshot init`

Generates a commented `simshot.yml` scaffold that documents the options you'd pass to `simshot shoot`. Interactive by default; `--yes` writes it with placeholder values.

```bash
simshot init --yes   # → simshot.yml (commented template)
```

### `simshot verify`

Checks the tree `simshot shoot` produced against Apple's screenshot rules; anything App Store Connect would reject fails here first (exit `1`), so it works as a CI gate.

```bash
simshot shoot --project MyApp.xcodeproj --scheme MyApp \
  --bundle-id com.example.myapp --devices iphone-17-pro-max \
  --langs ja,en --scenes home,detail --resize
simshot verify appstore --devices iphone-17-pro-max --langs ja,en
```

```text
simshot verify — appstore

✅ iphone-17-pro-max/ja  3 files  1290×2796 (6.7inch)
❌ iphone-17-pro-max/en  2 files  1290×2796 (6.7inch)

❌ iphone-17-pro-max/en/02_detail.png
   image has an alpha channel — App Store Connect rejects these
   → run shoot with `--resize` to write flattened App Store copies
```

It flags dimensions that aren't an accepted size, an alpha channel, mixed sizes inside one folder, and empty or missing device/language folders. `raw/` is skipped, `--devices`/`--langs` require those folders to exist, and `--json` gives the same report for tooling.

## `simshot shoot` reference

```
BUILD
  --project <path.xcodeproj>       Xcode project to build (or --workspace)
  --workspace <path.xcworkspace>   Xcode workspace to build
  --scheme <name>                  Scheme to build
  --app-path <path.app>            Skip building; use an existing .app bundle

REQUIRED
  --bundle-id <id>                 App bundle identifier
  --devices <list>                 Simulator names or UDIDs (comma-separated)

SHOTS
  --shots <config.json>            Shot config file ({ "shots": [...] })
  --scenes <list>                  Shortcut: one shot per scene, e.g. home,trace
  --wait <secs>                    Default settle time per shot for --scenes (default: 6)

LOCALIZATION
  --langs <list>                   Languages (default: en), e.g. ja,en
  --locales <map>                  lang=locale overrides, e.g. ja=ja_JP,en=en_US

OUTPUT
  --output <dir>                   Output directory (default: appstore)
  --resize                         Write App Store-ready copies (alpha removed)
  --derived-data <dir>             DerivedData path (default: ~/.simshot/DerivedData)

SIMULATOR
  --timeout <secs>                 Timeout for external commands (default: 300)
  --status-bar-time <t>            Status bar clock (default: 9:41)
  --status-bar-battery <n>         Status bar battery % (default: 100)
  --no-ui-testing                  Do not pass --ui-testing to the app
  --no-clean                       Do not uninstall before installing
  --keep-running                   Do not shut down simulators afterwards

MISC
  --verbose, -v                    Verbose output
  --help, -h                       Show help
```

### Devices

`--devices` accepts either device names or UDIDs:

```bash
simshot shoot ... --devices iphone-17-pro-max,ipad-pro-13
simshot shoot ... --devices 67DF6727-31BC-4246-9FC0-313A22FB2A6C
```

Names are matched case-insensitively and hyphen/dash-insensitively. When the same name exists on several iOS runtimes, the **newest runtime** wins. Output subdirectories use the name you passed (or the device slug when using a UDID).

### Shot config

`shots.json` gives full control over names, scenes, and settle times. Every field except `name` and `scene` is optional.

```json
{
  "shots": [
    { "name": "04_home.png", "scene": "home", "wait": 8 },
    { "name": "01_trace.png", "scene": "trace", "strokes": 1, "wait": 6 },
    { "name": "06_store.png", "scene": "store", "wait": 8 },
    { "name": "07_store_tip.png", "scene": "store", "scrollBottom": true, "wait": 8 }
  ]
}
```

| Field | Type | Default | Meaning |
|---|---|---|---|
| `name` | string | — | Output filename, e.g. `04_home.png` |
| `scene` | string | — | Scene name passed as `--screenshot-scene` |
| `strokes` | int | `nil` | Passed as `--screenshot-strokes` |
| `scrollBottom` | bool | `false` | Passes `--screenshot-scroll-bottom` |
| `wait` | int | `6` | Seconds to wait after launch before capturing |
| `uiTesting` | bool | `true` | Whether to pass `--ui-testing` |

The file may be either a bare array of shots or `{ "shots": [...] }`.

## Screenshot scene protocol

simshot launches your app with a fixed argument set. **Your app owns the scene names and what they do** — simshot only passes them through.

| Argument | Meaning |
|---|---|
| `--ui-testing` | Tell the app this is an automated session (skip onboarding etc.). |
| `--screenshot-scene <scene>` | Navigate to the named scene on launch. |
| `--screenshot-strokes <N>` | Perform N interactions (e.g. draw N strokes). Optional. |
| `--screenshot-scroll-bottom` | Scroll the scene to the bottom before capturing. Optional. |

In addition, simshot always passes `-AppleLanguages (lang)` and `-AppleLocale locale` so the app renders in the requested language.

### App-side implementation (SwiftUI)

```swift
import SwiftUI

struct HomeView: View {
    @State private var path: [Character] = []
    @State private var showSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            content
                .onAppear {
                    #if DEBUG
                    handleScreenshotScene()
                    #endif
                }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    #if DEBUG
    /// Screenshot-capture support: interpret simshot's launch arguments.
    private func handleScreenshotScene() {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--screenshot-scene"),
              index + 1 < args.count else { return }
        let scene = args[index + 1]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            switch scene {
            case "detail":
                if let first = characters.first {
                    path = [first]
                }
            case "settings":
                showSettings = true
            default:
                break // "home" is the default screen
            }
        }
    }
    #endif
}
```

Because the handler lives behind `#if DEBUG`, it never ships in a release build.

## Resizing

`--resize` writes App Store-ready copies to `<output>/<device>/<lang>/`. simshot:

1. Detects the raw capture's aspect ratio and picks the matching App Store size (exact dimension match first — this disambiguates same-ratio devices like the iPad Pro 13" and iPad 10.2").
2. Flattens any alpha channel onto white.
3. Resizes with high-quality interpolation (LANCZOS-equivalent) and writes PNG.

Supported targets:

| Size | Device |
|---|---|
| 1320×2868 | iPhone 16 Pro Max / 17 Pro Max (6.9") |
| 1290×2796 | iPhone 15 Pro Max (6.7") |
| 1242×2688 | iPhone 11 Pro Max (6.5") |
| 2064×2752 | iPad Pro 13-inch |
| 2048×2732 | iPad Pro 12.9-inch |
| 2266×1488 | iPad Pro 11-inch |
| 2160×1620 | iPad 10.2-inch |

If no target matches (within 1% aspect ratio), simshot warns and keeps the raw capture.

## Output layout

```
appstore/
├── raw/
│   └── iphone-17-pro-max/
│       ├── ja/
│       │   ├── 04_home.png
│       │   └── 01_trace.png
│       └── en/
│           └── 04_home.png
└── iphone-17-pro-max/            # --resize: App Store-ready copies
    └── ja/
        └── 04_home.png
```

## Reliability

- **Timeout**: every external command (xcodebuild, simctl, …) is killed if it exceeds `--timeout`. A hung simulator can never stall a CI job.
- **Retries**: `launch`, `install`, and `screenshot` retry on failure.
- **Per-device isolation**: a failing device is reported and skipped without aborting the rest of the matrix.
- **Clean state**: the app is uninstalled before install, and `--keep-running`/`--no-clean` are opt-outs if you want to preserve state.

## Development

```bash
swift build   # build
swift test    # run tests
swift format lint --recursive Sources Tests   # code style
swift run simshot shoot --help
```

## License

[MIT](LICENSE)
