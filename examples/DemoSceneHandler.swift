import SwiftUI

// MARK: - Screenshot scene launch-argument protocol (dummy app sample)
//
// simshot launches your app with a fixed set of arguments and expects the app
// (under `#if DEBUG`) to navigate to the requested scene:
//
//   --ui-testing                  automatic capture session (skip onboarding, etc.)
//   --screenshot-scene <scene>    navigate to <scene> on launch
//   --screenshot-strokes <N>      perform N interactions (optional)
//   --screenshot-scroll-bottom    scroll to the bottom before capturing (optional)
//
// simshot also passes `-AppleLanguages (lang)` and `-AppleLocale <locale>`, which
// the system uses to render the app in the requested language — no app code needed.
//
// Scene names are YOURS. simshot only passes them through. This file is a drop-in
// example: copy `handleScreenshotScene()` into your root view's `onAppear` and add
// your own scenes to the `switch`.

struct DemoSceneHandler: ViewModifier {
    @State private var path: [String] = []
    @State private var showSettings = false

    func body(content: Content) -> some View {
        NavigationStack(path: $path) {
            content
                .onAppear {
                    #if DEBUG
                    handleScreenshotScene()
                    #endif
                }
        }
        .sheet(isPresented: $showSettings) {
            Text("Settings").font(.title)
        }
    }

    #if DEBUG
    private func handleScreenshotScene() {
        let args = ProcessInfo.processInfo.arguments

        // Bail unless simshot started us for a specific scene.
        guard let index = args.firstIndex(of: "--screenshot-scene"),
              index + 1 < args.count else { return }
        let scene = args[index + 1]

        // Wait a beat for the root view to settle before navigating.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            switch scene {
            case "home":
                break  // the default screen
            case "detail":
                path = ["Some Item"]  // push into the navigation stack
            case "settings":
                showSettings = true  // present a sheet
            default:
                break  // unknown scene: stay on the default screen
            }

            if args.contains("--screenshot-strokes") {
                drawStrokes()
            }
            if args.contains("--screenshot-scroll-bottom") {
                scrollToBottom()
            }
        }
    }

    /// Perform N interactions (e.g. draw N strokes into the canvas).
    private func drawStrokes() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--screenshot-strokes"),
              i + 1 < args.count,
              let count = Int(args[i + 1]) else { return }
        // Trigger the drawing engine `count` times. This is app-specific.
        // Example: for _ in 0..<count { canvasViewModel.addStroke() }
        _ = count
    }

    /// Scroll the current scroll view to its bottom edge.
    private func scrollToBottom() {
        // Post a scroll-to-bottom notification or drive your ScrollView's
        // scrollPosition reader. This is app-specific.
    }
    #endif
}

extension View {
    func demoSceneHandler() -> some View {
        modifier(DemoSceneHandler())
    }
}
