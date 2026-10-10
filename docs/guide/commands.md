# Commands

| Command | Description |
|---|---|
| `simshot shoot <options>` | Build, boot, capture, and resize screenshots. |
| `simshot devices` | List available simulators (name + UDID). |
| `simshot doctor` | Diagnose the local Xcode / simulator environment (exit 1 on problems). |
| `simshot init` | Generate a commented `simshot.yml` config scaffold. |
| `simshot verify [dir]` | Check captured screenshots against App Store requirements (exit 1 on problems). |
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
✅ Xcode: Xcode 27.0
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

## `simshot verify`

Walks the output tree from `simshot shoot` and reports anything App Store Connect
would reject or ignore, so a bad capture fails CI instead of failing review.

- dimensions that are not an accepted App Store screenshot size
- an alpha channel (rejected at upload)
- mixed sizes inside one device/language folder
- empty or missing device/language folders

`raw/` (the untouched `simctl` captures) is skipped — `verify` inspects the App
Store copies, so run `shoot` with `--resize` first.

```text
$ simshot verify appstore --devices iphone-17-pro-max --langs ja,en
simshot verify — appstore

✅ iphone-17-pro-max/ja  3 files  1290×2796 (6.7inch)
❌ iphone-17-pro-max/en  2 files  1290×2796 (6.7inch)

❌ iphone-17-pro-max/en/02_detail.png
   image has an alpha channel — App Store Connect rejects these
   → run shoot with `--resize` to write flattened App Store copies
```

Options: `--devices <list>` and `--langs <list>` require those folders to exist
(a silently-missing language is the most common packaging bug), and `--json`
prints the same report as machine-readable JSON. Exit code is `0` when every
checked screenshot is publishable and `1` otherwise.

## Reliability

- **Timeout**: every external command (xcodebuild, simctl, …) is killed if it exceeds `--timeout`. A hung simulator can never stall a CI job.
- **Retries**: `launch`, `install`, and `screenshot` retry on failure.
- **Per-device isolation**: a failing device is reported and skipped without aborting the rest of the matrix.
- **Clean state**: the app is uninstalled before install, and `--keep-running`/`--no-clean` are opt-outs if you want to preserve state.
