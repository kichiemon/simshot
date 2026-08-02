import Foundation
import SimshotCore

enum Command {
    case shoot(ShootOptions)
    case devices
    case version
    case help
}

@main
struct SimshotCLI {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        do {
            try execute(command: parse(args))
        } catch {
            Log.error("❌ \(error)")
            Log.error("")
            Log.error(Help.shoot)
            exit(1)
        }
    }

    static func parse(_ args: [String]) throws -> Command {
        if args.isEmpty {
            return .help
        }
        switch args[0] {
        case "shoot":
            let rest = Array(args.dropFirst())
            if rest.contains("--help") || rest.contains("-h") {
                return .help
            }
            return .shoot(try ArgParser.parseShoot(rest))
        case "devices":
            return .devices
        case "version", "--version", "-V":
            return .version
        case "help", "--help", "-h":
            return .help
        default:
            throw SimshotError.usage("Unknown command '\(args[0])'")
        }
    }

    static func execute(command: Command) throws {
        switch command {
        case .shoot(let options):
            try ShootRunner(options: options).run()
        case .devices:
            try listDevices()
        case .version:
            print("simshot \(simshotVersion)")
        case .help:
            print(Help.main)
        }
    }

    static func listDevices() throws {
        let simulators = try Simulator.listAvailable()
        guard !simulators.isEmpty else {
            print("No available simulators. Run `xcrun simctl list devices available` to check.")
            return
        }
        for simulator in simulators {
            print("\(simulator.name)\t\(simulator.udid)")
        }
    }
}
