# Changelog

All notable changes to simshot are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Nothing yet.

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

[Unreleased]: https://github.com/kichiemon/simshot/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/kichiemon/simshot/releases/tag/v0.1.0
