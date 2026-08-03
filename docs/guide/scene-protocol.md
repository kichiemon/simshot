# Screenshot Scene Protocol

simshot launches your app with a fixed argument set. **Your app owns the scene names and what they do** — simshot only passes them through.

| Argument | Meaning |
|---|---|
| `--ui-testing` | Tell the app this is an automated session (skip onboarding etc.). |
| `--screenshot-scene <scene>` | Navigate to the named scene on launch. |
| `--screenshot-strokes <N>` | Perform N interactions (e.g. draw N strokes). Optional. |
| `--screenshot-scroll-bottom` | Scroll the scene to the bottom before capturing. Optional. |

In addition, simshot always passes `-AppleLanguages (lang)` and `-AppleLocale locale` so the app renders in the requested language (no app-side implementation needed).

> This protocol is a public contract. Changing it requires updating this page, the README (en/ja/ko), and `Sources/SimshotCore/ShotSpec.swift`.

## App-side implementation (SwiftUI)

A complete sample is in `examples/DemoSceneHandler.swift`. The gist: interpret the launch arguments in the root view's `onAppear` and navigate to the matching scene:

```swift
import SwiftUI

struct HomeView: View {
    @State private var path: [Character] = []
    @State private var showSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            content
                .onAppear {
                    #if DEBUG
                    handleScreenshotScene()
                    #endif
                }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    #if DEBUG
    /// Screenshot-capture support: interpret simshot's launch arguments.
    private func handleScreenshotScene() {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--screenshot-scene"),
              index + 1 < args.count else { return }
        let scene = args[index + 1]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            switch scene {
            case "detail":
                if let first = characters.first {
                    path = [first]
                }
            case "settings":
                showSettings = true
            default:
                break // "home" is the default screen
            }
        }
    }
    #endif
}
```

Because the handler lives behind `#if DEBUG`, it never ships in a release build.

## Launch-argument reference

The exact arguments simshot passes to the app on every launch:

| Argument | Present when |
|---|---|
| `--ui-testing` | always (unless `--no-ui-testing`) |
| `--screenshot-scene <scene>` | always |
| `--screenshot-strokes <N>` | `strokes` set in `shots.json` |
| `--screenshot-scroll-bottom` | `scrollBottom: true` in `shots.json` |
| `-AppleLanguages (lang)` | always |
| `-AppleLocale <locale>` | always |
