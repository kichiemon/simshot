# Contributing to simshot

Thanks for taking the time to contribute! simshot is a small, focused CLI and we
want to keep it that way — every line of code should earn its place.

## Project values

- **Zero dependencies.** simshot only uses Foundation / CoreGraphics / ImageIO /
  UniformTypeIdentifiers. Before adding a package, ask whether the problem can
  be solved with what Apple ships.
- **`simctl` only.** The whole point is "no XCUITest, no flaky runners, no
  hangs." Keep the tool that way.
- **No hardcoded device/bundle/scene values.** Everything comes from CLI
  arguments or the shots config.
- **Timeouts everywhere.** Every external command must go through
  `ProcessRunner` with a timeout.

## Getting started

```bash
swift build   # build
swift test    # run tests
swift run simshot shoot --help
```

## What to work on

Check the [issues](https://github.com/kichiemon/simshot/issues) for open bugs
and feature requests. If you plan a bigger change, open an issue first so we can
agree on the direction before you invest time in code.

## Development workflow

1. Fork the repo and create a feature branch.
2. Make your change. Add tests for any new pure logic (argument building, target
   matching, config decoding, image processing).
3. Make sure formatting and tests pass:

   ```bash
   swift-format lint --recursive Sources Tests
   swift build && swift test
   ```

4. Commit with a clear message that describes *why* the change was made.
5. Open a pull request.

## Pull request guidelines

- Keep PRs focused and reviewable. Split large changes into smaller PRs.
- Update `README.md`, `README.ja.md`, `README.ko.md`, and `llms.txt` when you
  change user-facing behavior (especially the screenshot scene protocol).
- Update `CHANGELOG.md` under an `[Unreleased]` heading.
- The scene launch-argument protocol is a **public contract**. Changing it must
  be reflected in the three READMEs and `Sources/SimshotCore/ShotSpec.swift`.

## Reporting bugs

Open an issue with the `bug` template. Include the full command you ran, the
exact error output, and your environment (`simshot doctor` output is ideal).

## Code of conduct

Please note that this project is released with a
[Contributor Code of Conduct](CODE_OF_CONDUCT.md). By participating you agree to
abide by its terms.
