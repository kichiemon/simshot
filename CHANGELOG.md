# Changelog

All notable changes to simshot are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

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

[Unreleased]: https://github.com/kichiemon/simshot/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/kichiemon/simshot/releases/tag/v0.2.0
[0.1.1]: https://github.com/kichiemon/simshot/releases/tag/v0.1.1
[0.1.0]: https://github.com/kichiemon/simshot/releases/tag/v0.1.0
