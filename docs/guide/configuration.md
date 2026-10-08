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

1. Matches the raw capture against Apple's published screenshot sizes — exact dimensions first, then aspect ratio within 1%. A capture that is already an accepted size keeps its own resolution instead of being upscaled.
2. Flattens any alpha channel onto white.
3. Resizes with high-quality interpolation (LANCZOS-equivalent) and writes PNG.

Sizes accepted for current devices, in either orientation (`verify` also accepts Apple's older sizes, down to the 3.5-inch iPhone):

| Size | Device |
|---|---|
| 1320×2868 | iPhone 16 Pro Max / 17 Pro Max (6.9") |
| 1290×2796 | iPhone 14 Pro Max / 15 Plus / 16 Plus (6.7") |
| 1260×2736 | iPhone Air (6.5") |
| 1284×2778 | iPhone 12 Pro Max / 13 Pro Max |
| 1242×2688 | iPhone 11 Pro Max / XS Max (6.5") |
| 1206×2622 | iPhone 16 Pro / 17 Pro (6.3") |
| 1179×2556 | iPhone 15 / 16 / 17 (6.1") |
| 1170×2532 | iPhone 12 / 13 / 14 |
| 1125×2436 | iPhone X / XS / 11 Pro |
| 1080×2340 | iPhone 12 mini |
| 1242×2208 | iPhone 6 Plus / 8 Plus |
| 750×1334 | iPhone 8 / SE (2nd, 3rd gen) |
| 2064×2752 | iPad Pro 13-inch |
| 2048×2732 | iPad Pro 12.9-inch |
| 1668×2420 | iPad Pro 11-inch (M4, M5) |
| 1668×2388 | iPad Pro 11-inch (2018-2022) |
| 2266×1488 | iPad mini (6th gen, A17 Pro) |
| 1640×2360 | iPad Air 11-inch / iPad (10th gen, A16) |
| 1668×2224 | iPad Pro 10.5-inch / iPad (9th gen) |
| 1536×2048 | iPad 9.7-inch |
| 768×1024 | iPad mini |

A 10.2-inch iPad screen captures at 2160×1620, which App Store Connect does not accept (that display class submits at 1668×2224), so the raw capture is resized to the iPad 13-inch size rather than passed through.

If no target matches (within 1% aspect ratio), simshot warns and keeps the raw capture.
