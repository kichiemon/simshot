import Foundation

public enum SimcapError: Error, CustomStringConvertible {
    case usage(String)
    case commandFailed(String)
    case timeout(String)
    case notFound(String)
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

public enum Log {
    public static var verbose = false

    public static func info(_ message: String) {
        print(message)
    }

    public static func detail(_ message: String) {
        if verbose {
            print(message)
        }
    }

    public static func warn(_ message: String) {
        write(message, to: FileHandle.standardError)
    }

    public static func error(_ message: String) {
        write(message, to: FileHandle.standardError)
    }

    private static func write(_ message: String, to handle: FileHandle) {
        if let data = (message + "\n").data(using: .utf8) {
            handle.write(data)
        }
    }
}

public let simcapVersion = "0.1.0"
