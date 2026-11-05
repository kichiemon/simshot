# Changelog

All notable changes to simshot are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `simshot shoot --app-path` no longer requires `--bundle-id`: the bundle
  identifier is read from the `.app`'s `Info.plist` (`CFBundleIdentifier`) when
  `--bundle-id` is omitted. An explicit `--bundle-id` still takes precedence.
  `XcodeBuild.bundleIdentifier(at:)` exposes the same read for reuse.

### Fixed

- `Simulator.runtimeComponents` now ignores the device-family suffix that newer
  Xcode runtimes append to their identifier (e.g.
  `com.apple.CoreSimulator.SimRuntime.iOS-27-2-iPhone19-4`). Previously every
  integer in the identifier was collected, turning that runtime into `[27, 2, 4]`
  and making it look newer than a plain `iOS-27-2` runtime (`[27, 2]`) when
  `simshot` picks which runtime to use for a duplicate device name. Only the
  leading OS-version segments are now parsed, so runtime ordering stays correct.
- `XcodeBuild.findApp` now locates the built `.app` in any `*-iphonesimulator`
  configuration directory (e.g. `Release-iphonesimulator`), not just
  `Debug-iphonesimulator`, and also handles `.app` bundles placed directly under
  `Build/Products`. Previously a Release (or otherwise non-Debug) build made
  `simshot shoot` fail with "Could not find a built .app" even though the
  bundle existed. Selection is now deterministic (Debug preferred, then name
  order).
- `simshot doctor` now counts only iOS runtimes in the "iOS runtimes" check.
  On toolchains that also have watchOS/tvOS/visionOS runtimes installed, the
  previous count included every platform, so the reported number was inflated
  and could mask a missing iOS runtime.
- `simshot shoot` now rejects contradictory or empty inputs at parse time:
  `--project` and `--workspace` together, and empty values for `--project`,
  `--workspace`, `--app-path`, `--output`, `--derived-data`, and
  `--status-bar-time`. These used to slip through and fail later (or, for
  `--app-path ""`, silently resolve to the current working directory).
- `simshot shoot` now rejects invalid shot entries at parse time instead of
  failing later or writing outside the output tree: an empty `name` or `scene`,
  a negative `wait` or `strokes`, and a `name` that looks like a path (contains
  a separator or is `.`/`..`). The error names the offending entry, e.g.
  `shots[0].name: name must not be empty`.

- `simshot verify` now flags a device/language folder that holds more than 10
  screenshots, since App Store Connect accepts at most 10 per device display
  size. Reported as `too-many-screenshots` (exit `1`).
- `simshot shoot` now rejects `--scenes`, `--langs`, and `--devices` entries that
  look like paths (contain a separator or are `.`/`..`) at parse time, and trims
  whitespace around `--locales` keys and values. These used to slip through and
  could write outside the output tree or collapse to the current/parent
  directory.

## [0.2.2] - 2026-10-18

### Fixed

- `simshot shoot` now rejects nonsensical numeric options at parse time instead
  of failing confusingly later: `--timeout` must be positive (a `0` used to
  parse fine and force-kill xcodebuild on its first check with a misleading
  "timed out" error), `--wait` must not be negative, and
  `--status-bar-battery` must be 0-100 (bad values used to only fail after a
  full build and simulator boot, when simctl rejected them).
- `simshot verify` no longer passes an output tree that holds nothing to check.
  An empty output directory, a `raw/`-only tree (a `shoot` run without
  `--resize`), and a device folder with no language folders inside it all used
  to print `✅ 0 screenshots in 0 folders are App Store-ready.` and exit `0`, so
  a CI gate went green on a tree with no publishable screenshot in it. Each now
  reports the empty directory and exits `1`. With `--devices`, a folder that
  exists but contains no language folder fails the same way instead of passing.
- The `verify` text report no longer prints stray blank lines around the folder
  list, and its failure summary now lands after the report instead of above it
  when stdout is piped (CI logs, `simshot verify > log`).

## [0.2.1] - 2026-10-10

### Fixed

- The App Store size table now matches Apple's published list. Two things were
  wrong before. `verify` rejected sizes App Store Connect accepts — an iPad Air
  10.9-inch capture (1640×2360, and its 11-inch siblings 1668×2420 and
  1668×2388), an iPhone 17 at 1179×2556, an iPhone SE at 750×1334 — and asked
  for a resize that was never needed. It also accepted 2160×1620, which is the
  iPad 10.2-inch screen resolution rather than an upload size, so a file App
  Store Connect rejects passed the gate. `--resize` no longer upscales: a
  capture that is already an accepted size keeps its resolution and only gets
  its alpha flattened, and a raw 10.2-inch iPad capture is resized to the
  required iPad 13-inch size.
- A shots config that is valid JSON but has a bad field now fails with the
  offending path and reason, e.g. `shots[1] is missing required key 'scene'` or
  `shots[0].wait has the wrong type`, plus the config path. Previously any
  decode failure reported "shots config must be a JSON array of shots or
  { \"shots\": [...] }", which was wrong for a correctly-shaped file. The form
  (bare array vs `{ "shots": [...] }`) is now chosen from the top-level JSON, so
  the path in the message matches what the user wrote.

## [0.2.0] - 2026-10-05

### Added

- `simshot verify [dir]` — check an output tree against App Store screenshot
  requirements and exit `1` on any problem, so a bad capture fails CI instead of
  failing review at upload. Flags dimensions that aren't an accepted size, an
  alpha channel, mixed sizes inside one device/language folder, and empty or
  missing folders. `raw/` is skipped; `--devices`/`--langs` require those folders
  to exist; `--json` prints a machine-readable report. All logic lives in
  `Verifier` (SimshotCore) with `VerifierTests` covering each finding.

## [0.1.1] - 2026-08-02

### Added

- Single binary distribution: `arm64 + x86_64` universal build; GitHub Releases
  now attach raw `simshot-macos-arm64` / `simshot-macos-x86_64` executables, plus
  `.tar.gz` archives and `.sha256` checksums for each. This enables `curl`
  one-liner, `nix`, `mise (ubi)`, and npm installs without a Swift toolchain.
- One-line curl install (`curl -sL .../simshot-macos-{arm64,x86_64} -o /usr/local/bin/simshot && chmod +x /usr/local/bin/simshot`).
- `flake.nix` — fetches the prebuilt single binary from GitHub Releases via
  `fetchurl`; supports `nix run github:kichiemon/simshot` and
  `nix profile install github:kichiemon/simshot`.
- mise/ubi install path (`mise use ubi:kichiemon/simshot`) — ubi resolves the
  `simshot-macos-{os}-{arch}` release assets.
- npm `install.js` now downloads the single binary directly (arm64/x86_64) with
  sha256 verification; publishing to npm still requires an npm account, so the
  package is prepared but not published.
- Homebrew tap formula at [`kichiemon/homebrew-tap`](https://github.com/kichiemon/homebrew-tap)
  (`Formula/simshot.rb`) updated to the `v0.1.1` prebuilt binary.
- npm distribution package (`npm/`): `package.json`, `install.js`, and a
  `cli.js` bin wrapper.

## [0.1.0] - 2026-08-02

### Added

- `simshot shoot` — build the app, boot simulators, override the status bar,
  launch each scene via the screenshot scene launch-argument protocol, capture
  with `simctl io screenshot`, and resize to App Store sizes (`--resize`).
- `simshot devices` — list available simulators (name + UDID).
- `simshot doctor` — diagnose xcode-select / Xcode / simctl / iOS runtimes /
  available simulators (exits 1 on failure).
- `simshot init` — generate a commented `simshot.yml` config scaffold
  (interactive, or non-interactive with `--yes`).
- `simshot version` / `simshot help`.
- `--shots <config.json>` and `--scenes` shot definition with per-shot
  `wait`, `strokes`, `scrollBottom`, and `uiTesting` control.
- Device × language matrix with `--langs` and `--locales` overrides.
- App Store resizing (alpha flattening + LANCZOS-equivalent interpolation)
  via CoreGraphics/ImageIO with zero third-party dependencies.
- Hard timeout + retry wrapper for every external command (no hangs).
- GitHub Actions CI (`.github/workflows/ci.yml`) and release pipeline
  (`.github/workflows/release.yml`).
- README in English, Japanese, and Korean.

[Unreleased]: https://github.com/kichiemon/simshot/compare/v0.2.2...HEAD
[0.2.2]: https://github.com/kichiemon/simshot/releases/tag/v0.2.2
[0.2.1]: https://github.com/kichiemon/simshot/releases/tag/v0.2.1
[0.2.0]: https://github.com/kichiemon/simshot/releases/tag/v0.2.0
[0.1.1]: https://github.com/kichiemon/simshot/releases/tag/v0.1.1
[0.1.0]: https://github.com/kichiemon/simshot/releases/tag/v0.1.0
