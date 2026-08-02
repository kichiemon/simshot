# AGENTS.md

simcap — App Store screenshot capture CLI (simctl only, no XCUITest).

## Commands

```bash
swift build                # build the CLI (product: simcap)
swift test                 # run the test suite
swift run simcap shoot --help   # CLI help
swift run simcap devices    # list available simulators
```

## Project layout

- `Sources/SimcapCore/` — core library (framework-free, macOS 13+):
  - `ProcessRunner.swift` — external command wrapper with hard timeout + retry.
  - `Simctl.swift` — `simctl` operations and device listing/resolution.
  - `XcodeBuild.swift` — `xcodebuild` wrapper and `.app` discovery.
  - `ShotSpec.swift` — screenshot scene launch-argument protocol + shot config decoding.
  - `DeviceSpec.swift` — App Store size targets and aspect-ratio matching.
  - `Resizer.swift` — alpha flattening + resize via CoreGraphics/ImageIO (no PIL).
  - `Support.swift` — `SimcapError`, `Log`, version.
- `Sources/simcap/` — CLI entry point (`CLI.swift`), argument parsing (`Options.swift`), the shoot orchestrator (`ShootRunner.swift`), help text (`Help.swift`).
- `Tests/simcapTests/` — XCTest suite.
- `examples/shots.json` — sample shot config.

## Conventions

- **No hardcoded device UDIDs, bundle IDs, or scene names.** Everything is passed via CLI arguments or the shots config. Scene names are defined by the app, not by simcap.
- Keep the dependency footprint zero: only Foundation / CoreGraphics / ImageIO / UniformTypeIdentifiers. Do not add third-party packages without a strong reason.
- The screenshot scene protocol (`--screenshot-scene`, `--screenshot-strokes`, `--screenshot-scroll-bottom`, `--ui-testing`) is a public contract — changing it must be reflected in `README.md`, `README.ja.md`, and `Sources/SimcapCore/ShotSpec.swift`.
- All external commands must go through `ProcessRunner` with a timeout.
- Add tests for new pure logic (argument building, target matching, config decoding, image processing).

## Verification

Before committing, run:

```bash
swift build && swift test
```
