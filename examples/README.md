# Examples

This directory contains samples that show how to use simshot.

| File | What it shows |
|---|---|
| [`shots.json`](shots.json) | A complete shot config for a real capture run. |
| [`DemoSceneHandler.swift`](DemoSceneHandler.swift) | A drop-in implementation of the screenshot scene launch-argument protocol (SwiftUI). |

## `DemoSceneHandler.swift` — implementing the protocol

simshot does not drive your UI. Your app must interpret the launch arguments that
simshot passes to `simctl launch`. The protocol is:

| Argument | Meaning |
|---|---|
| `--ui-testing` | This is an automated session — skip onboarding, banners, etc. |
| `--screenshot-scene <scene>` | Navigate to the named scene on launch. |
| `--screenshot-strokes <N>` | Perform N interactions (e.g. draw N strokes). Optional. |
| `--screenshot-scroll-bottom` | Scroll the scene to the bottom before capturing. Optional. |

simshot always adds `-AppleLanguages (lang)` and `-AppleLocale locale`; the system
uses these to render the app in the requested language.

### How to wire it in

1. Copy `DemoSceneHandler.swift` into your app target.
2. Attach the modifier to your root view:

   ```swift
   @main
   struct MyApp: App {
       var body: some Scene {
           WindowGroup {
               ContentView()
                   .demoSceneHandler()
           }
       }
   }
   ```

3. Add your own scenes to the `switch` inside `handleScreenshotScene()`.

Everything lives behind `#if DEBUG`, so the handler never ships in a release build.

### Try it end to end

Point simshot at your app with the scenes your handler knows about:

```bash
simshot shoot --project MyApp.xcodeproj --scheme MyApp \
  --bundle-id com.example.myapp \
  --devices iphone-17-pro-max --langs ja,en \
  --scenes home,detail,settings --output appstore --resize
```

Raw captures land in `appstore/raw/iphone-17-pro-max/<lang>/` and resized
App Store copies (with `--resize`) in `appstore/iphone-17-pro-max/<lang>/`.
