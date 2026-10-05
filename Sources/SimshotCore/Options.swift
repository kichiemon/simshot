import Foundation

/// All options accepted by `simshot shoot`, as parsed from CLI arguments.
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

/// Command-line argument parsing for `simshot shoot`.
public enum ArgParser {
    /// Parse raw CLI arguments into a validated `ShootOptions`.
    ///
    /// Throws `SimshotError.usage` for unknown flags, missing values, or
    /// missing required options.
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

    /// Fill defaults and reject incomplete option sets.
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

    /// Split a comma-separated value into trimmed, non-empty tokens.
    public static func csv(_ value: String) -> [String] {
        value.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Parse `lang=locale,lang=locale` overrides.
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

    /// Load and decode a shots config file (array or `{ "shots": [...] }`).
    static func loadShots(_ path: String) throws -> [Shot] {
        let url = URL(fileURLWithPath: path)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw SimshotError.notFound("Cannot read shots config: \(path)")
        }
        let decoder = JSONDecoder()
        // Pick the form from the top-level JSON shape instead of guessing, so a
        // failure inside a `{ "shots": [...] }` file names the path the user
        // actually wrote (`shots[1].scene`, not `[1].scene`).
        let isObject = (try? JSONSerialization.jsonObject(with: data)) is [String: Any]
        do {
            if isObject {
                return try decoder.decode(ShotsFile.self, from: data).shots
            }
            return try decoder.decode([Shot].self, from: data)
        } catch let error as DecodingError {
            throw SimshotError.invalid("Invalid shots config \(path): \(describe(error))")
        } catch {
            throw SimshotError.invalid("Invalid shots config \(path): \(error.localizedDescription)")
        }
    }

    /// Explain a `DecodingError` in one line, naming the JSON path of the
    /// offending value: "shots[1] is missing required key 'scene'".
    static func describe(_ error: DecodingError) -> String {
        // Render a coding path as `shots[1].wait`, dropping the `shots` key so
        // the array form and the `{ "shots": [...] }` form read the same.
        func render(_ codingPath: [CodingKey]) -> String {
            var path = ""
            for key in codingPath where key.stringValue != "shots" {
                if let index = key.intValue {
                    path += "[\(index)]"
                } else {
                    path += path.isEmpty ? key.stringValue : ".\(key.stringValue)"
                }
            }
            if path.isEmpty { return "shots" }
            return path.hasPrefix("[") ? "shots\(path)" : "shots.\(path)"
        }

        switch error {
        case .keyNotFound(_, let context) where context.codingPath.isEmpty:
            return "missing the required top-level \"shots\" array"
        case .keyNotFound(let key, let context):
            return "\(render(context.codingPath)) is missing required key '\(key.stringValue)'"
        case .typeMismatch(_, let context):
            return "\(render(context.codingPath)) has the wrong type (\(context.debugDescription))"
        case .valueNotFound(_, let context):
            return "\(render(context.codingPath)) must not be null (\(context.debugDescription))"
        case .dataCorrupted(let context):
            return context.debugDescription
        @unknown default:
            return error.localizedDescription
        }
    }
}
