import Foundation
import SimshotCore

struct InitOptions {
    var yes = false
    var output = "simshot.yml"
}

enum Command {
    case shoot(ShootOptions)
    case devices
    case doctor
    case initConfig(InitOptions)
    case version
    case help(String)
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
            switch args.first {
            case "shoot": Log.error(Help.shoot)
            case "init": Log.error(Help.initHelp)
            case "doctor": Log.error(Help.doctor)
            default: Log.error(Help.main)
            }
            exit(1)
        }
    }

    static func parse(_ args: [String]) throws -> Command {
        if args.isEmpty {
            return .help(Help.main)
        }
        switch args[0] {
        case "shoot":
            let rest = Array(args.dropFirst())
            if rest.contains("--help") || rest.contains("-h") {
                return .help(Help.shoot)
            }
            return .shoot(try ArgParser.parseShoot(rest))
        case "devices":
            return .devices
        case "doctor":
            if args.contains("--help") || args.contains("-h") {
                return .help(Help.doctor)
            }
            return .doctor
        case "init":
            let rest = Array(args.dropFirst())
            if rest.contains("--help") || rest.contains("-h") {
                return .help(Help.initHelp)
            }
            return .initConfig(try parseInit(rest))
        case "version", "--version", "-V":
            return .version
        case "help", "--help", "-h":
            return .help(Help.main)
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
        case .doctor:
            try DoctorRunner.run()
        case .initConfig(let options):
            try InitRunner.run(yes: options.yes, output: options.output)
        case .version:
            print("simshot \(simshotVersion)")
        case .help(let text):
            print(text)
        }
    }

    static func parseInit(_ args: [String]) throws -> InitOptions {
        var options = InitOptions()
        var index = 0
        while index < args.count {
            let raw = args[index]
            switch raw {
            case "--yes", "-y":
                options.yes = true
            case "--output":
                guard index + 1 < args.count else {
                    throw SimshotError.usage("Missing value for --output")
                }
                index += 1
                options.output = args[index]
            default:
                throw SimshotError.usage("Unknown option '\(raw)'. Run `simshot init --help`.")
            }
            index += 1
        }
        return options
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
