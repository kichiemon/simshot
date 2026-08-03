# Troubleshooting

## `simshot doctor` fails (exit 1)

- **xcode-select / Xcode fails**: Make sure full Xcode (not just command line tools) is installed. `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
- **iOS runtimes fails**: Add an iOS runtime in Xcode > Settings > Platforms.
- **Available simulators warns**: Create a device with `xcrun simctl create` or in Xcode > Window > Devices and Simulators.

## `simshot shoot` errors

### "Unknown device"

Check names/UDIDs with `simshot devices`. `--devices` matches with newest-runtime preference, but passing an explicit UDID is the most reliable.

### No screenshot / black screen

Make sure the app interprets the scene launch-argument protocol under `#if DEBUG`. With `--no-ui-testing`, `--ui-testing` is not passed, so onboarding may appear.

### Capture hangs mid-run

Every external command is force-killed by `--timeout` (default 300s), and launch / install / screenshot auto-retry. Raise `--timeout 600` or use `--verbose` to see where it stalls.

### Not resized

Did you pass `--resize`? If the aspect ratio deviates more than 1% from supported sizes, simshot warns and skips.

### Want to skip the build

Use `--app-path <path.app>` with an existing `.app`.

## Capturing from a clean state

By default the app is uninstalled → installed, and the simulator is shut down afterwards. To keep state, use `--no-clean` / `--keep-running`.

## Resize warnings

- **Aspect ratio deviates from supported sizes**: the raw capture is kept as-is and a warning is printed. Supported sizes are listed in [Configuration](./configuration#resize-targets).
- **Alpha channel**: `--resize` flattens alpha onto white automatically, so transparent captures never fail App Store submission.

## Installation issues

- **`shasum: command not found`**: the install script requires macOS's built-in `shasum` (present on all supported macOS versions).
- **`curl: (22) The requested URL returned error: 404`**: the release tag does not exist. Check the tag with `SIMSHOT_VERSION` or use the latest release.
- **"Permission denied" on `/usr/local/bin`**: the install script falls back to `~/.local/bin` automatically. Or install with Homebrew.
- **`simshot` not found after install**: the install directory is not on your `PATH`. Add `export PATH="$HOME/.local/bin:$PATH"` to your shell profile.
