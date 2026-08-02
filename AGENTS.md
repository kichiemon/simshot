# AGENTS.md

simshot — App Store screenshot capture CLI (simctl only, no XCUITest).

## Commands

```bash
swift build                # build the CLI (product: simshot)
swift test                 # run the test suite
swift run simshot shoot --help   # CLI help
swift run simshot devices    # list available simulators
```

## Project layout

- `Sources/SimshotCore/` — core library (framework-free, macOS 13+):
  - `ProcessRunner.swift` — external command wrapper with hard timeout + retry.
  - `Simctl.swift` — `simctl` operations and device listing/resolution.
  - `XcodeBuild.swift` — `xcodebuild` wrapper and `.app` discovery.
  - `ShotSpec.swift` — screenshot scene launch-argument protocol + shot config decoding.
  - `DeviceSpec.swift` — App Store size targets and aspect-ratio matching.
  - `Resizer.swift` — alpha flattening + resize via CoreGraphics/ImageIO (no PIL).
  - `Support.swift` — `SimshotError`, `Log`, version.
- `Sources/simshot/` — CLI entry point (`CLI.swift`), argument parsing (`Options.swift`), the shoot orchestrator (`ShootRunner.swift`), help text (`Help.swift`).
- `Tests/simshotTests/` — XCTest suite.
- `examples/shots.json` — sample shot config.
- `.github/workflows/` — CI (`ci.yml`) and release (`release.yml`) pipelines.
- `llms.txt` — LLM-facing project summary; keep in sync with the READMEs.

## Conventions

- **No hardcoded device UDIDs, bundle IDs, or scene names.** Everything is passed via CLI arguments or the shots config. Scene names are defined by the app, not by simshot.
- Keep the dependency footprint zero: only Foundation / CoreGraphics / ImageIO / UniformTypeIdentifiers. Do not add third-party packages without a strong reason.
- The screenshot scene protocol (`--screenshot-scene`, `--screenshot-strokes`, `--screenshot-scroll-bottom`, `--ui-testing`) is a public contract — changing it must be reflected in `README.md`, `README.ja.md`, `README.ko.md`, and `Sources/SimshotCore/ShotSpec.swift`.
- All external commands must go through `ProcessRunner` with a timeout.
- Add tests for new pure logic (argument building, target matching, config decoding, image processing).

## Verification

Before committing, run:

```bash
swift build && swift test
```
