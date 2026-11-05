import Foundation

public enum XcodeBuild {
    /// Build a simulator Debug app and return the `.app` bundle path.
    public static func build(
        project: String?,
        workspace: String?,
        scheme: String,
        derivedData: String,
        timeout: TimeInterval
    ) throws -> URL {
        var args: [String] = []
        if let project {
            args += ["-project", project]
        }
        if let workspace {
            args += ["-workspace", workspace]
        }
        args += [
            "-scheme", scheme,
            "-sdk", "iphonesimulator",
            "-destination", "generic/platform=iOS Simulator",
            "-derivedDataPath", derivedData,
            "-quiet",
            "build",
        ]

        Log.info("🔨 Building \(scheme)...")
        let result = try ProcessRunner.run("/usr/bin/xcodebuild", args, timeout: timeout)
        guard result.status == 0 else {
            let diagnostics = result.stdout + "\n" + result.stderr
            throw SimshotError.commandFailed("xcodebuild failed:\n\(diagnostics)")
        }
        guard let app = findApp(derivedDataPath: derivedData) else {
            throw SimshotError.notFound("Could not find a built .app under \(derivedData)/Build/Products/")
        }
        return app
    }

    /// Read the app's bundle identifier from its `Info.plist`.
    ///
    /// Returns `nil` when the plist is missing, unreadable, or has no
    /// `CFBundleIdentifier`, so callers can fall back to an explicit value.
    public static func bundleIdentifier(at appURL: URL) -> String? {
        let plistURL = appURL.appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: plistURL) else { return nil }
        guard
            let plist = try? PropertyListSerialization.propertyList(
                from: data, options: [], format: nil) as? [String: Any]
        else { return nil }
        guard let identifier = plist["CFBundleIdentifier"] as? String,
            !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return identifier.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Locate the built `.app` bundle inside a DerivedData directory.
    ///
    /// Handles both the common Debug layout (`Build/Products/Debug-iphonesimulator/`)
    /// and any other `*-iphonesimulator` configuration directory (e.g. Release),
    /// as well as `.app` bundles placed directly under `Build/Products`. Among
    /// multiple configurations the Debug one is preferred (Debug-named
    /// directories win; ties are broken alphabetically); within a directory the
    /// first `.app` in name order wins, so the result is deterministic.
    public static func findApp(derivedDataPath: String) -> URL? {
        let products = URL(fileURLWithPath: derivedDataPath).appendingPathComponent("Build/Products")
        guard
            let entries = try? FileManager.default.contentsOfDirectory(
                at: products, includingPropertiesForKeys: nil
            )
        else {
            return nil
        }
        // A `.app` placed directly under `Build/Products` wins.
        if let direct =
            entries
            .filter({ $0.pathExtension == "app" })
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            .first
        {
            return direct
        }
        // Otherwise look inside `*-iphonesimulator` configuration directories,
        // preferring Debug over Release (and any other configuration) and
        // returning the first `.app` in name order within the chosen one.
        let configDirs =
            entries
            .filter { $0.lastPathComponent.contains("iphonesimulator") }
            .sorted { lhs, rhs in
                let lDebug = lhs.lastPathComponent.localizedCaseInsensitiveContains("debug")
                let rDebug = rhs.lastPathComponent.localizedCaseInsensitiveContains("debug")
                if lDebug != rDebug { return lDebug }
                return lhs.lastPathComponent < rhs.lastPathComponent
            }
        for dir in configDirs {
            guard
                let apps = try? FileManager.default.contentsOfDirectory(
                    at: dir, includingPropertiesForKeys: nil
                )
            else { continue }
            if let app =
                apps
                .filter({ $0.pathExtension == "app" })
                .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
                .first
            {
                return app
            }
        }
        return nil
    }

}
