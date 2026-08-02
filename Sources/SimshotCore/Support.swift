import Foundation

/// The canonical error type for simshot. Every failure path in the codebase
/// throws one of these (or `ResizerError`), and the CLI prints `description`
/// as an actionable message before exiting.
public enum SimshotError: Error, CustomStringConvertible {
    /// Invalid CLI usage: unknown flags, missing values, or missing required
    /// options. Message is a remediation hint.
    case usage(String)
    /// An external command (xcodebuild / simctl / xcrun) exited non-zero.
    case commandFailed(String)
    /// An external command was killed because it exceeded its timeout.
    case timeout(String)
    /// A requested resource (file, simulator, device) could not be found.
    case notFound(String)
    /// Input data or environment output was malformed.
    case invalid(String)

    public var description: String {
        switch self {
        case .usage(let message):
            return message
        case .commandFailed(let message):
            return message
        case .timeout(let message):
            return "timed out: \(message)"
        case .notFound(let message):
            return message
        case .invalid(let message):
            return message
        }
    }
}

/// User-facing console output.
///
/// `info`/`detail` go to stdout (verbose gating), warnings and errors go to
/// stderr so they survive piping `simshot` output to a file.
public enum Log {
    /// When `true`, `detail` messages are printed.
    public static var verbose = false

    /// Print a normal progress message to stdout.
    public static func info(_ message: String) {
        print(message)
    }

    /// Print a verbose detail message to stdout (only when `verbose`).
    public static func detail(_ message: String) {
        if verbose {
            print(message)
        }
    }

    /// Print a warning to stderr.
    public static func warn(_ message: String) {
        write(message, to: FileHandle.standardError)
    }

    /// Print an error to stderr.
    public static func error(_ message: String) {
        write(message, to: FileHandle.standardError)
    }

    private static func write(_ message: String, to handle: FileHandle) {
        if let data = (message + "\n").data(using: .utf8) {
            handle.write(data)
        }
    }
}

/// The current simshot semantic version.
public let simshotVersion = "0.1.1"
