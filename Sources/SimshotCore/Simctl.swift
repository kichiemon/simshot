import Foundation

public struct Simulator: Equatable {
    public let name: String
    public let udid: String
    let runtimeComponents: [Int]

    public init(name: String, udid: String, runtimeComponents: [Int]) {
        self.name = name
        self.udid = udid
        self.runtimeComponents = runtimeComponents
    }

    /// A filesystem-safe slug derived from the device name, e.g.
    /// "iPhone 17 Pro Max" -> "iphone-17-pro-max".
    public var slug: String {
        let allowed = name.lowercased()
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "." || $0 == "," })
            .joined(separator: "-")
        return allowed.isEmpty ? udid : allowed
    }

    // MARK: - Listing & resolution

    /// Parse `simctl list devices available -j`.
    public static func listAvailable() throws -> [Simulator] {
        let result = try ProcessRunner.run(
            "/usr/bin/xcrun", ["simctl", "list", "devices", "available", "-j"],
            timeout: 30
        )
        guard result.status == 0 else {
            throw SimshotError.commandFailed("`simctl list devices` failed:\n\(result.stderr)")
        }
        guard let data = result.stdout.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devices = json["devices"] as? [String: Any] else {
            throw SimshotError.invalid("Could not parse `simctl list devices -j` output.")
        }

        var found: [Simulator] = []
        for (runtimeBundleID, entries) in devices {
            guard let list = entries as? [[String: Any]] else { continue }
            for item in list {
                guard let name = item["name"] as? String,
                      let udid = item["udid"] as? String,
                      (item["isAvailable"] as? Bool) ?? true else { continue }
                found.append(Simulator(name: name, udid: udid, runtimeComponents: runtimeComponents(of: runtimeBundleID)))
            }
        }
        return found.sorted { $0.name < $1.name }
    }

    /// Resolve a CLI token (device name or UDID) to a concrete simulator.
    /// Duplicate names across iOS runtimes are de-duplicated in favor of the
    /// newest runtime, so `--devices iphone-17-pro-max` just works.
    public static func resolve(_ token: String) throws -> Simulator {
        let devices = try listAvailable()

        // Full UUID -> exact match.
        if token.range(of: #"^[0-9A-Fa-f]{8}-[0-9A-Fa-f-]{27}$"#, options: .regularExpression) != nil {
            if let device = devices.first(where: { $0.udid.lowercased() == token.lowercased() }) {
                return device
            }
            throw SimshotError.notFound("No available simulator with UDID \(token). Run `simshot devices`.")
        }

        // Name -> substring match, newest runtime wins per distinct name.
        let normalized = token.replacingOccurrences(of: "-", with: " ").lowercased()
        var bestByName: [String: Simulator] = [:]
        for device in devices where device.name.lowercased().contains(normalized) {
            if let existing = bestByName[device.name] {
                if isNewer(device.runtimeComponents, than: existing.runtimeComponents) {
                    bestByName[device.name] = device
                }
            } else {
                bestByName[device.name] = device
            }
        }
        let matches = Array(bestByName.values)
        if matches.count == 1 {
            return matches[0]
        }
        if matches.isEmpty {
            throw SimshotError.notFound("No available simulator matching '\(token)'. Run `simshot devices` to list them.")
        }
        let names = matches.map { "  \($0.name) (\($0.udid))" }.joined(separator: "\n")
        throw SimshotError.invalid("'\(token)' matched multiple simulators:\n\(names)\nBe more specific.")
    }

    /// Extract numeric version components from a runtime bundle ID,
    /// e.g. "com.apple.CoreSimulator.SimRuntime.iOS-26-4" -> [26, 4].
    static func runtimeComponents(of bundleID: String) -> [Int] {
        guard let marker = bundleID.split(separator: ".").last else { return [] }
        return marker.split(separator: "-")
            .compactMap { Int($0) }
    }

    /// Compare two version component arrays lexicographically.
    /// e.g. [26, 5] is newer than [26, 4].
    static func isNewer(_ lhs: [Int], than rhs: [Int]) -> Bool {
        let maxCount = max(lhs.count, rhs.count)
        for index in 0..<maxCount {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right {
                return left > right
            }
        }
        return false
    }

    // MARK: - simctl operations

    public func boot(timeout: TimeInterval = 180) throws {
        Log.info("🚀 Booting \(name) (\(udid))...")
        let result = try ProcessRunner.run(
            "/usr/bin/xcrun", ["simctl", "bootstatus", udid, "-b"],
            timeout: timeout
        )
        guard result.status == 0 else {
            throw SimshotError.commandFailed("simctl bootstatus failed for \(name):\n\(result.stderr)")
        }
    }

    public func overrideStatusBar(
        time: String = "9:41",
        batteryLevel: Int = 100,
        wifiBars: Int = 3,
        cellularBars: Int = 3
    ) throws {
        Log.info("📶 Overriding status bar (\(time) / \(batteryLevel)%)...")
        let result = try ProcessRunner.run(
            "/usr/bin/xcrun",
            [
                "simctl", "status_bar", udid, "override",
                "--time", time,
                "--batteryState", "charged",
                "--batteryLevel", String(batteryLevel),
                "--wifiBars", String(wifiBars),
                "--cellularBars", String(cellularBars),
            ],
            timeout: 30
        )
        guard result.status == 0 else {
            throw SimshotError.commandFailed("simctl status_bar override failed for \(name):\n\(result.stderr)")
        }
    }

    public func clearStatusBar() {
        _ = try? ProcessRunner.run(
            "/usr/bin/xcrun", ["simctl", "status_bar", udid, "clear"],
            timeout: 15
        )
    }

    public func uninstallApp(bundleID: String) {
        let result = try? ProcessRunner.run(
            "/usr/bin/xcrun", ["simctl", "uninstall", udid, bundleID],
            timeout: 60
        )
        if let result, result.status != 0 {
            Log.detail("uninstall (ignored): \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
    }

    public func installApp(_ appURL: URL) throws {
        Log.info("📲 Installing \(appURL.lastPathComponent)...")
        var lastError = ""
        for attempt in 1...2 {
            let result = try ProcessRunner.run(
                "/usr/bin/xcrun", ["simctl", "install", udid, appURL.path],
                timeout: 120
            )
            if result.status == 0 { return }
            lastError = result.stderr
            Log.warn("⚠️  install attempt \(attempt) failed, retrying...")
            Thread.sleep(forTimeInterval: 2.0)
        }
        throw SimshotError.commandFailed("simctl install failed for \(name):\n\(lastError)")
    }

    public func launch(bundleID: String, arguments: [String], retries: Int = 2, timeout: TimeInterval = 60) throws {
        var lastError = ""
        for attempt in 1...max(1, retries) {
            let result = try ProcessRunner.run(
                "/usr/bin/xcrun", ["simctl", "launch", udid, bundleID] + arguments,
                timeout: timeout
            )
            if result.status == 0 { return }
            lastError = result.stderr
            Log.warn("⚠️  launch attempt \(attempt) failed: \(lastError.trimmingCharacters(in: .whitespacesAndNewlines))")
            if attempt < retries {
                Thread.sleep(forTimeInterval: 2.0)
            }
        }
        throw SimshotError.commandFailed("simctl launch failed for \(bundleID) on \(name):\n\(lastError)")
    }

    public func terminate(bundleID: String) {
        _ = try? ProcessRunner.run(
            "/usr/bin/xcrun", ["simctl", "terminate", udid, bundleID],
            timeout: 20
        )
    }

    public func screenshot(to url: URL, retries: Int = 3, timeout: TimeInterval = 30) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var lastError = ""
        for attempt in 1...max(1, retries) {
            let result = try ProcessRunner.run(
                "/usr/bin/xcrun", ["simctl", "io", udid, "screenshot", url.path],
                timeout: timeout
            )
            if result.status == 0 { return }
            lastError = result.stderr
            Log.warn("⚠️  screenshot attempt \(attempt) failed: \(lastError.trimmingCharacters(in: .whitespacesAndNewlines))")
            Thread.sleep(forTimeInterval: 1.5)
        }
        throw SimshotError.commandFailed("simctl screenshot failed on \(name):\n\(lastError)")
    }

    public func shutdown() {
        _ = try? ProcessRunner.run(
            "/usr/bin/xcrun", ["simctl", "shutdown", udid],
            timeout: 30
        )
    }
}
