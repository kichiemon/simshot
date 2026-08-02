import Foundation
import SimshotCore

public struct ShootRunner {
    let options: ShootOptions

    public init(options: ShootOptions) {
        self.options = options
    }

    public func run() throws {
        Log.verbose = options.verbose

        // 1. Build (or use an existing .app).
        let appURL: URL
        if let appPath = options.appPath {
            appURL = appPath
        } else {
            guard let scheme = options.scheme else {
                throw SimshotError.usage("--scheme is required")
            }
            appURL = try XcodeBuild.build(
                project: options.project,
                workspace: options.workspace,
                scheme: scheme,
                derivedData: options.derivedData,
                timeout: options.timeout
            )
        }
        Log.info("📦 App: \(appURL.path)")

        // 2. Resolve every requested device (names or UDIDs).
        var devicePairs: [(token: String, simulator: Simulator)] = []
        for token in options.devices {
            let simulator = try Simulator.resolve(token)
            Log.info("📱 \(simulator.name) → \(simulator.udid)")
            devicePairs.append((token, simulator))
        }

        // 3. Capture device × language. Continue on per-device failure so one
        //    broken simulator doesn't abort the whole matrix; fail at the end.
        var failures: [String] = []
        for (token, simulator) in devicePairs {
            do {
                try capture(simulator, deviceDir: deviceDirName(token: token, simulator: simulator), appURL: appURL)
            } catch {
                let message = "\(simulator.name): \(error)"
                failures.append(message)
                Log.error("❌ \(message)")
                simulator.shutdown()
            }
        }

        if !failures.isEmpty {
            throw SimshotError.commandFailed("Capture failed for:\n- " + failures.joined(separator: "\n- "))
        }
        Log.info("✅ Done! Screenshots saved to \(options.outputDir)/")
    }

    // MARK: - Per device

    func capture(_ simulator: Simulator, deviceDir: String, appURL: URL) throws {
        try simulator.boot(timeout: options.timeout)
        try simulator.overrideStatusBar(time: options.statusBarTime, batteryLevel: options.statusBarBattery)

        if options.cleanInstall {
            Log.detail("🧹 Uninstalling previous install of \(options.bundleID)...")
            simulator.uninstallApp(bundleID: options.bundleID)
        }
        try simulator.installApp(appURL)

        for lang in options.languages {
            let locale = options.localeOverrides[lang] ?? LocaleMap.locale(for: lang)
            Log.info("📸 Capturing \(simulator.name) / \(lang)...")

            for shot in options.shots {
                simulator.terminate(bundleID: options.bundleID)
                Thread.sleep(forTimeInterval: 0.5)

                let launchArgs = ScreenshotProtocol.launchArguments(language: lang, locale: locale, shot: shot)
                Log.detail("   🚀 launch: \(launchArgs.joined(separator: " "))")
                try simulator.launch(bundleID: options.bundleID, arguments: launchArgs)

                Log.detail("   ⏳ waiting \(shot.wait)s for scene '\(shot.scene)'...")
                Thread.sleep(forTimeInterval: TimeInterval(shot.wait))

                let rawDir = "\(options.outputDir)/raw/\(deviceDir)/\(lang)"
                let rawPath = "\(rawDir)/\(shot.name)"
                try simulator.screenshot(to: URL(fileURLWithPath: rawPath))
                Log.info("   📸 \(deviceDir)/\(lang)/\(shot.name)")

                if options.resize {
                    try resizeToAppStore(
                        inputPath: rawPath,
                        outputDir: options.outputDir,
                        deviceDir: deviceDir,
                        lang: lang,
                        name: shot.name
                    )
                }
            }
        }

        simulator.terminate(bundleID: options.bundleID)
        simulator.clearStatusBar()
        if options.shutdownAfter {
            Log.info("🧹 Shutting down \(simulator.name)...")
            simulator.shutdown()
        }
    }

    // MARK: - Resize

    func resizeToAppStore(inputPath: String, outputDir: String, deviceDir: String, lang: String, name: String) throws {
        let inputURL = URL(fileURLWithPath: inputPath)
        let image = try Resizer.loadCGImage(at: inputURL)
        guard let target = DeviceSpec.matchTarget(width: image.width, height: image.height) else {
            Log.warn("   ⚠️  No App Store size matches \(image.width)x\(image.height) for \(name); skipping resize")
            return
        }
        let outDir = "\(outputDir)/\(deviceDir)/\(lang)"
        try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        let outputURL = URL(fileURLWithPath: "\(outDir)/\(name)")
        try Resizer.makeAppStoreImage(input: inputURL, output: outputURL, target: target)
        Log.info("   🖼  \(name): \(image.width)x\(image.height) → \(Int(target.size.width))x\(Int(target.size.height)) [\(target.name)]")
    }

    func deviceDirName(token: String, simulator: Simulator) -> String {
        let isUDID = token.range(of: #"^[0-9A-Fa-f]{8}-[0-9A-Fa-f-]{27}$"#, options: .regularExpression) != nil
        if isUDID {
            return simulator.slug
        }
        let normalized = token.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        return normalized.isEmpty ? simulator.slug : normalized
    }
}
