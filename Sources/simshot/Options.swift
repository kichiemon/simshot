import Foundation
import SimshotCore

public struct ShootOptions {
    public var project: String?
    public var workspace: String?
    public var scheme: String?
    public var appPath: URL?
    public var bundleID = ""
    public var devices: [String] = []
    public var languages: [String] = []
    public var localeOverrides: [String: String] = [:]
    public var scenes: [String] = []
    public var shots: [Shot] = []
    public var outputDir = "appstore"
    public var derivedData = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".simshot/DerivedData")
        .path
    public var timeout: TimeInterval = 300
    public var wait = 6
    public var resize = false
    public var uiTesting = true
    public var cleanInstall = true
    public var shutdownAfter = true
    public var verbose = false
    public var statusBarTime = "9:41"
    public var statusBarBattery = 100

    public init() {}
}

public enum ArgParser {
    public static func parseShoot(_ args: [String]) throws -> ShootOptions {
        var options = ShootOptions()
        var index = 0

        func takeValue(for flag: String, inline: String?, _ index: inout Int) throws -> String {
            if let inline { return inline }
            guard index + 1 < args.count else {
                throw SimshotError.usage("Missing value for \(flag)")
            }
            index += 1
            return args[index]
        }

        while index < args.count {
            let raw = args[index]
            guard raw.hasPrefix("--") || raw.hasPrefix("-"), !raw.isEmpty else {
                throw SimshotError.usage("Unexpected positional argument '\(raw)'")
            }
            var flag = raw
            var inline: String?
            if let equals = raw.firstIndex(of: "=") {
                flag = String(raw[raw.startIndex..<equals])
                inline = String(raw[raw.index(after: equals)...])
            }

            switch flag {
            case "--project":
                options.project = try takeValue(for: flag, inline: inline, &index)
            case "--workspace":
                options.workspace = try takeValue(for: flag, inline: inline, &index)
            case "--scheme":
                options.scheme = try takeValue(for: flag, inline: inline, &index)
            case "--app-path":
                options.appPath = URL(fileURLWithPath: try takeValue(for: flag, inline: inline, &index))
            case "--bundle-id":
                options.bundleID = try takeValue(for: flag, inline: inline, &index)
            case "--devices":
                options.devices = csv(try takeValue(for: flag, inline: inline, &index))
            case "--langs":
                options.languages = csv(try takeValue(for: flag, inline: inline, &index))
            case "--locales":
                options.localeOverrides = try parseLocales(try takeValue(for: flag, inline: inline, &index))
            case "--scenes":
                options.scenes = csv(try takeValue(for: flag, inline: inline, &index))
            case "--shots":
                options.shots = try loadShots(try takeValue(for: flag, inline: inline, &index))
            case "--output":
                options.outputDir = try takeValue(for: flag, inline: inline, &index)
            case "--derived-data":
                options.derivedData = try takeValue(for: flag, inline: inline, &index)
            case "--timeout":
                guard let value = TimeInterval(try takeValue(for: flag, inline: inline, &index)) else {
                    throw SimshotError.usage("--timeout must be a number of seconds")
                }
                options.timeout = value
            case "--wait":
                guard let value = Int(try takeValue(for: flag, inline: inline, &index)) else {
                    throw SimshotError.usage("--wait must be an integer number of seconds")
                }
                options.wait = value
            case "--status-bar-time":
                options.statusBarTime = try takeValue(for: flag, inline: inline, &index)
            case "--status-bar-battery":
                guard let value = Int(try takeValue(for: flag, inline: inline, &index)) else {
                    throw SimshotError.usage("--status-bar-battery must be an integer")
                }
                options.statusBarBattery = value
            case "--resize":
                options.resize = true
            case "--no-ui-testing":
                options.uiTesting = false
            case "--no-clean":
                options.cleanInstall = false
            case "--keep-running":
                options.shutdownAfter = false
            case "--verbose", "-v":
                options.verbose = true
            default:
                throw SimshotError.usage("Unknown option '\(raw)'. Run `simshot shoot --help`.")
            }
            index += 1
        }

        try validate(&options)
        return options
    }

    static func validate(_ options: inout ShootOptions) throws {
        if options.appPath == nil {
            guard options.project != nil || options.workspace != nil else {
                throw SimshotError.usage("Either --project/--workspace or --app-path is required.")
            }
            guard let scheme = options.scheme, !scheme.isEmpty else {
                throw SimshotError.usage("--scheme is required.")
            }
        }
        guard !options.bundleID.isEmpty else {
            throw SimshotError.usage("--bundle-id is required.")
        }
        guard !options.devices.isEmpty else {
            throw SimshotError.usage("--devices is required (e.g. iphone-17-pro-max,ipad-pro-13).")
        }
        if options.languages.isEmpty {
            options.languages = ["en"]
        }
        if options.shots.isEmpty {
            guard !options.scenes.isEmpty else {
                throw SimshotError.usage("Provide --shots <config.json> or --scenes home,trace,...")
            }
            options.shots = options.scenes.map {
                Shot(name: "\($0).png", scene: $0, wait: options.wait, uiTesting: options.uiTesting)
            }
        }
    }

    static func csv(_ value: String) -> [String] {
        value.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func parseLocales(_ value: String) throws -> [String: String] {
        var result: [String: String] = [:]
        for pair in csv(value) {
            let parts = pair.split(separator: "=")
            guard parts.count == 2 else {
                throw SimshotError.usage("Invalid --locales entry '\(pair)' (expected lang=locale)")
            }
            result[String(parts[0])] = String(parts[1])
        }
        return result
    }

    static func loadShots(_ path: String) throws -> [Shot] {
        let url = URL(fileURLWithPath: path)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw SimshotError.notFound("Cannot read shots config: \(path)")
        }
        let decoder = JSONDecoder()
        if let file = try? decoder.decode(ShotsFile.self, from: data) {
            return file.shots
        }
        if let shots = try? decoder.decode([Shot].self, from: data) {
            return shots
        }
        throw SimshotError.invalid(
            "shots config must be a JSON array of shots or { \"shots\": [...] }. See README."
        )
    }
}
