import Foundation
import SimshotCore

/// Options for `simshot verify`.
struct VerifyOptions {
    var root = "appstore"
    var devices: [String] = []
    var languages: [String] = []
    var json = false
}

/// Runs `simshot verify` and prints a human or JSON report.
///
/// Exit code mirrors the report: 0 when everything is publishable, 1 when any
/// issue was found, so it drops straight into CI.
enum VerifyRunner {
    static func run(_ options: VerifyOptions) throws {
        let report = Verifier.verify(
            root: URL(fileURLWithPath: options.root),
            devices: options.devices,
            languages: options.languages
        )

        if options.json {
            print(try jsonReport(report))
        } else {
            printTextReport(report)
        }

        if !report.ok {
            exit(1)
        }
    }

    /// The whole report goes to stdout as one block, so piped output keeps its
    /// order; the failure summary goes to stderr so CI logs and `$?` both see it.
    static func printTextReport(_ report: VerifyReport) {
        var lines: [String] = ["simshot verify — \(report.root)", ""]

        for folder in report.folders {
            let bad = report.issues.contains { $0.path == folder.path || $0.path.hasPrefix(folder.path + "/") }
            var line = "\(bad ? "❌" : "✅") \(folder.path)  \(folder.fileCount) file\(folder.fileCount == 1 ? "" : "s")"
            if let size = folder.size {
                line += "  \(Int(size.width))×\(Int(size.height))"
            }
            if let target = folder.target {
                line += " (\(target.name))"
            }
            lines.append(line)
        }

        if !report.issues.isEmpty {
            lines.append("")
            for issue in report.issues {
                lines.append("❌ \(issue.path)")
                lines.append("   \(issue.message)")
                lines.append("   → \(issue.fix)")
            }
        }

        lines.append("")
        if report.ok {
            lines.append(
                "✅ \(report.checkedFiles) screenshot\(report.checkedFiles == 1 ? "" : "s") in "
                    + "\(report.folders.count) folder\(report.folders.count == 1 ? "" : "s") are App Store-ready.")
        }
        if !report.skipped.isEmpty {
            lines.append(
                "note: skipped \(report.skipped.joined(separator: ", ")) "
                    + "(run shoot with `--resize` for App Store copies)")
        }
        Log.info(lines.joined(separator: "\n"))

        if !report.ok {
            Log.error(
                "❌ \(report.issues.count) problem\(report.issues.count == 1 ? "" : "s") in "
                    + "\(report.folders.count) folder\(report.folders.count == 1 ? "" : "s") "
                    + "(\(report.checkedFiles) file\(report.checkedFiles == 1 ? "" : "s") checked)")
        }
    }

    static func jsonReport(_ report: VerifyReport) throws -> String {
        var folders: [[String: Any]] = []
        for folder in report.folders {
            var entry: [String: Any] = [
                "device": folder.device,
                "language": folder.language,
                "path": folder.path,
                "fileCount": folder.fileCount,
            ]
            if let size = folder.size {
                entry["size"] = ["width": Int(size.width), "height": Int(size.height)]
            }
            if let target = folder.target {
                entry["target"] = target.name
            }
            folders.append(entry)
        }

        let root: [String: Any] = [
            "root": report.root,
            "ok": report.ok,
            "checkedFiles": report.checkedFiles,
            "skipped": report.skipped,
            "folders": folders,
            "issues": report.issues.map { issue in
                ["kind": issue.kind.rawValue, "path": issue.path, "message": issue.message, "fix": issue.fix]
            },
        ]

        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
