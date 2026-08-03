# Commands

| Command | Description |
|---|---|
| `simshot shoot <options>` | Build, boot, capture, and resize screenshots. |
| `simshot devices` | List available simulators (name + UDID). |
| `simshot doctor` | Diagnose the local Xcode / simulator environment (exit 1 on problems). |
| `simshot init` | Generate a commented `simshot.yml` config scaffold. |
| `simshot version` | Print the version. |
| `simshot help` | Show help. |

## `simshot shoot`

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

## `simshot doctor`

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

## `simshot devices`

Lists available simulators as `name` + `UDID`. Useful to confirm the exact device names or UDIDs for `--devices`.

## `simshot init`

Generates a commented `simshot.yml` scaffold that documents the options you'd pass to `simshot shoot`. Interactive by default; `--yes` writes it with placeholder values.

```bash
simshot init --yes   # → simshot.yml (commented template)
```

## Reliability

- **Timeout**: every external command (xcodebuild, simctl, …) is killed if it exceeds `--timeout`. A hung simulator can never stall a CI job.
- **Retries**: `launch`, `install`, and `screenshot` retry on failure.
- **Per-device isolation**: a failing device is reported and skipped without aborting the rest of the matrix.
- **Clean state**: the app is uninstalled before install, and `--keep-running`/`--no-clean` are opt-outs if you want to preserve state.
