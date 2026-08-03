# Configuration

## `simshot.yml`

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

## `shots.json`

For per-shot control (wait seconds, strokes, scrollBottom), pass `--shots <shots.json>` to `simshot shoot`. See `examples/shots.json`.

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

## Devices

`--devices` accepts either device names or UDIDs:

```bash
simshot shoot ... --devices iphone-17-pro-max,ipad-pro-13
simshot shoot ... --devices 67DF6727-31BC-4246-9FC0-313A22FB2A6C
```

Names are matched case-insensitively and hyphen/dash-insensitively. When the same name exists on several iOS runtimes, the **newest runtime** wins. Output subdirectories use the name you passed (or the device slug when using a UDID).

## Resize targets

`--resize` writes App Store-ready copies to `<output>/<device>/<lang>/`. simshot:

1. Detects the raw capture's aspect ratio and picks the matching App Store size (exact dimension match first).
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
