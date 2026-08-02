---
name: simshot
description: How to use the "simshot" CLI, which captures App Store screenshots from the iOS Simulator using only simctl (no XCUITest, no hangs). It builds and boots the app in a simulator, navigates to each scene via a launch-argument protocol, captures the screens, and resizes them to App Store sizes. Load this skill when handling requests related to App Store screenshots, iOS simulator captures, simctl, simshot shoot / doctor / init / devices, or automated screenshot capture.
metadata:
  author: kichiemon
  version: "2.0.0"
---

# simshot — App Store screenshot capture CLI

simshot is a CLI that captures App Store submission screenshots from the iOS Simulator automatically. It drives **`simctl` only — no XCUITest** — so there are no test-runner hangs or flaky failures.

- Repo: <https://github.com/kichiemon/simshot>
- macOS 13+ / Swift 5.9+ / zero dependencies (Foundation / CoreGraphics / ImageIO only)
- Use case: generating App Store screenshots for a pre-release iOS app

The workflow is: build → boot the simulator → override the status bar → launch each scene → capture → resize to App Store sizes. The app under test only needs to implement a tiny `#if DEBUG` handler that interprets the launch-argument protocol.

## Installation

If you are an agent using this skill, simshot is usually already installed. If you need the simshot CLI itself, use one of the following:

### npx (as an agent skill)

```bash
npx skills add kichiemon/simshot
```

Skill-aware agents (Claude Code, opencode, etc.) then pick it up automatically. After installing, just ask for "App Store screenshots" and the agent will assemble and run `simshot shoot`.

### Single binary (curl, macOS)

```bash
# Apple Silicon (arm64)
curl -sL https://github.com/kichiemon/simshot/releases/download/v0.1.1/simshot-macos-arm64 -o /usr/local/bin/simshot && chmod +x /usr/local/bin/simshot

# Intel (x86_64)
curl -sL https://github.com/kichiemon/simshot/releases/download/v0.1.1/simshot-macos-x86_64 -o /usr/local/bin/simshot && chmod +x /usr/local/bin/simshot
```

### Nix

```bash
nix run github:kichiemon/simshot                # run without installing
nix profile install github:kichiemon/simshot    # install into your profile
```

The repo's `flake.nix` fetches the prebuilt single binary from GitHub Releases (no source build).

### mise (ubi)

```bash
mise use -g ubi:kichiemon/simshot   # install into your global config
simshot --version
```

mise resolves the `simshot-macos-{os}-{arch}` release assets via its ubi backend.

### Homebrew (tap)

```bash
brew tap kichiemon/homebrew-tap
brew install simshot
```

### npm (npmjs.com)

```bash
npm i -g simshot
npx simshot shoot
```

Requires macOS (arm64 / x86_64) + Node.js 14+. The `postinstall` script downloads a prebuilt single binary from GitHub Releases (implementation in `npm/`) and verifies its sha256. The npm package is prepared but not yet published.

### Build from source

```bash
git clone https://github.com/kichiemon/simshot.git
cd simshot
swift build -c release
ln -s "$(pwd)/.build/release/simshot" /usr/local/bin/simshot
```

## Quick start

```bash
# 1. Diagnose the environment (Xcode / simctl / runtimes / simulators)
simshot doctor

# 2. List available simulators
simshot devices

# 3. Capture screenshots (scene names specified directly)
simshot shoot --project MyApp.xcodeproj --scheme MyApp \
  --bundle-id com.example.myapp \
  --devices iphone-17-pro-max,ipad-pro-13 \
  --langs ja,en --scenes home,detail,settings \
  --output appstore --resize
```

Results are saved to `appstore/<device>/<lang>/NN_name.png`.

## simshot.yml configuration

`simshot init` (`--yes` for non-interactive) generates a commented `simshot.yml` scaffold. It documents the options you pass to `simshot shoot`. **Each key maps 1:1 to a `simshot shoot` flag**, and `simshot shoot` does not read this file automatically — pass the values as CLI flags.

```bash
simshot init --yes   # → generates a commented simshot.yml
```

Excerpt of the generated scaffold:

```yaml
# simshot configuration
project: MyApp.xcodeproj              # Xcode project to build
# workspace: MyApp.xcworkspace        # Alternative: Xcode workspace
scheme: MyApp                         # Scheme to build
bundle-id: com.example.myapp          # App bundle identifier (required)
output: appstore                      # Output directory
resize: true                          # Also write App Store-ready resized copies

# Simulator names or UDIDs to capture.
devices:
  - iphone-17-pro-max
  - ipad-pro-13

# Languages to capture (locale is derived, or use --locales for overrides).
langs:
  - ja
  - en

# Scenes captured as one shot each. For per-shot control (wait, strokes,
# scrollBottom), use --shots <shots.json> instead (see examples/shots.json).
scenes:
  - home
  - detail
  - settings
```

For per-shot control (wait seconds, strokes, scrollBottom), pass `--shots <shots.json>` to `simshot shoot`. See `examples/shots.json`.

## Scene launch-argument protocol specification

simshot launches the app with a fixed set of arguments. **Scene names and their behavior are up to the app** — simshot only passes them through. This protocol is a public contract; changing it requires updating `README.md` / `README.ja.md` / `README.ko.md` / `Sources/SimshotCore/ShotSpec.swift`.

| Argument | Meaning |
|---|---|
| `--ui-testing` | Signals an automated capture session (skips onboarding, etc.). |
| `--screenshot-scene <scene>` | Navigates to the given scene right after launch. |
| `--screenshot-strokes <N>` | Performs N interactions (e.g. N drawing strokes). Optional. |
| `--screenshot-scroll-bottom` | Scrolls the scene to the bottom before capturing. Optional. |

simshot also always passes `-AppleLanguages (lang)` and `-AppleLocale <locale>`, so the app renders in the requested language (no app-side implementation needed).

### App-side implementation example (SwiftUI)

A complete sample is in `examples/DemoSceneHandler.swift`. The gist: interpret the launch arguments in the root view's `onAppear` and navigate to the matching scene:

```swift
#if DEBUG
private func handleScreenshotScene() {
    let args = ProcessInfo.processInfo.arguments
    guard let index = args.firstIndex(of: "--screenshot-scene"),
          index + 1 < args.count else { return }
    let scene = args[index + 1]
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        switch scene {
        case "detail":
            path = [first]
        case "settings":
            showSettings = true
        default:
            break // "home" is the initial screen
        }
        if args.contains("--screenshot-strokes") { drawStrokes() }
        if args.contains("--screenshot-scroll-bottom") { scrollToBottom() }
    }
}
#endif
```

Because the handler lives inside `#if DEBUG`, it never ships in release builds.

## Command reference

| Command | Description |
|---|---|
| `simshot shoot <options>` | Build, launch, capture, and resize in one run. |
| `simshot devices` | List available simulators (name + UDID). |
| `simshot doctor` | Diagnose the local Xcode / simulator environment (exit 1 on problems). |
| `simshot init [--yes] [--output <path>]` | Generate a commented `simshot.yml` scaffold. |
| `simshot version` | Print the version. |
| `simshot help` | Show help. |

### `simshot shoot`

```
BUILD
  --project <path.xcodeproj>       Xcode project (mutually exclusive with --workspace)
  --workspace <path.xcworkspace>   Xcode workspace
  --scheme <name>                  Scheme name
  --app-path <path.app>            Use an existing .app without building

REQUIRED
  --bundle-id <id>                 App bundle identifier
  --devices <list>                 Simulator names or UDIDs (comma-separated)

SHOTS
  --shots <config.json>            Shot config file ({ "shots": [...] })
  --scenes <list>                  Shortcut: one shot per scene (e.g. home,trace)
  --wait <secs>                    Settle time per shot for --scenes (default: 6)

LOCALIZATION
  --langs <list>                   Languages (default: en), e.g. ja,en
  --locales <map>                  lang=locale overrides (e.g. ja=ja_JP,en=en_US)

OUTPUT
  --output <dir>                   Output directory (default: appstore)
  --resize                         Also write App Store-ready copies (alpha removed)
  --derived-data <dir>             DerivedData path (default: ~/.simshot/DerivedData)

SIMULATOR
  --timeout <secs>                 Timeout for external commands (default: 300)
  --status-bar-time <t>            Status bar clock (default: 9:41)
  --status-bar-battery <n>         Status bar battery % (default: 100)
  --no-ui-testing                  Do not pass --ui-testing to the app
  --no-clean                       Do not uninstall the app before installing
  --keep-running                   Do not shut down simulators afterwards

MISC
  --verbose, -v                    Verbose output
  --help, -h                       Show help
```

- `--devices` accepts device names (case- and hyphen-insensitive) or UDIDs. For duplicate names across runtimes, the newest runtime wins.
- The `--shots` JSON is `{ "shots": [...] }` (a bare array also works). Each shot requires `name` / `scene`; `strokes` / `scrollBottom` / `wait` (default 6) / `uiTesting` (default true) are optional.

### `simshot doctor`

Checks `xcode-select` / Xcode / `simctl` / iOS runtimes / available simulators and exits `1` on any failure. Run it when setting up a new machine or before reporting a bug.

```
$ simshot doctor
✅ xcode-select: /Applications/Xcode.app/Contents/Developer
✅ Xcode: Xcode 26.5
✅ simctl: found
✅ iOS runtimes: 7 installed
✅ Available simulators: 36 available

✅ All checks passed.
```

### `simshot init`

Generates a commented `simshot.yml` scaffold documenting the options to pass to `simshot shoot`. Interactive by default; `--yes` writes the placeholder values directly.

```bash
simshot init --yes   # → simshot.yml (commented template)
```

## Output directory

```
appstore/
├── raw/
│   └── iphone-17-pro-max/
│       ├── ja/
│       │   ├── 04_home.png
│       │   └── 01_trace.png
│       └── en/
│           └── 04_home.png
└── iphone-17-pro-max/            # --resize: App Store submission copies
    └── ja/
        └── 04_home.png
```

`--resize` picks an App Store size from the raw image's aspect ratio, flattens alpha onto white, resizes with LANCZOS-equivalent interpolation, and saves as PNG. Supported sizes: iPhone 1320×2868 / 1290×2796 / 1242×2688, iPad 2064×2752 / 2048×2732 / 2266×1488 / 2160×1620. If the aspect ratio deviates by more than 1%, a warning is printed and the raw image is kept as-is.

## Troubleshooting

### `simshot doctor` fails (exit 1)

- **xcode-select / Xcode fails**: Make sure full Xcode (not just command line tools) is installed. `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
- **iOS runtimes fails**: Add an iOS runtime in Xcode > Settings > Platforms.
- **Available simulators warns**: Create a device with `xcrun simctl create` or in Xcode > Window > Devices and Simulators.

### `simshot shoot` errors

- **"Unknown device"**: Check names/UDIDs with `simshot devices`. `--devices` matches with newest-runtime preference, but passing an explicit UDID is the most reliable.
- **No screenshot / black screen**: Make sure the app interprets the scene launch-argument protocol under `#if DEBUG`. With `--no-ui-testing`, `--ui-testing` is not passed, so onboarding may appear.
- **Capture hangs mid-run**: Every external command is force-killed by `--timeout` (default 300s), and launch / install / screenshot auto-retry. Raise `--timeout 600` or use `--verbose` to see where it stalls.
- **Not resized**: Did you pass `--resize`? If the aspect ratio deviates more than 1% from supported sizes, simshot warns and skips.
- **Want to skip the build**: Use `--app-path <path.app>` with an existing .app.

### Capturing from a clean state

By default the app is uninstalled → installed, and the simulator is shut down afterwards. To keep state, use `--no-clean` / `--keep-running`.

## Development

```bash
swift build   # build
swift test    # run tests
swift format lint --recursive Sources Tests   # code style
swift run simshot shoot --help
```
