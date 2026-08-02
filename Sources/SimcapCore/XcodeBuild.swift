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
            throw SimcapError.commandFailed("xcodebuild failed:\n\(diagnostics)")
        }
        guard let app = findApp(derivedDataPath: derivedData) else {
            throw SimcapError.notFound("Could not find a built .app under \(derivedData)/Build/Products/")
        }
        return app
    }

    /// Locate the built `.app` bundle inside a DerivedData directory.
    public static func findApp(derivedDataPath: String) -> URL? {
        let products = URL(fileURLWithPath: derivedDataPath).appendingPathComponent("Build/Products")
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: products, includingPropertiesForKeys: nil
        ) else {
            return nil
        }
        for entry in entries where entry.pathExtension == "app" {
            return entry
        }
        let debugDir = products.appendingPathComponent("Debug-iphonesimulator")
        guard let apps = try? FileManager.default.contentsOfDirectory(
            at: debugDir, includingPropertiesForKeys: nil
        ) else {
            return nil
        }
        return apps.first { $0.pathExtension == "app" }
    }
}
