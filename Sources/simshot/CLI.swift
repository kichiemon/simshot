import Foundation
import SimshotCore

enum Command {
    case shoot(ShootOptions)
    case devices
    case doctor
    case initConfig(InitOptions)
    case verify(VerifyOptions)
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
            case "verify": Log.error(Help.verify)
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
            return .initConfig(try ArgParser.parseInit(rest))
        case "verify":
            let rest = Array(args.dropFirst())
            if rest.contains("--help") || rest.contains("-h") {
                return .help(Help.verify)
            }
            return .verify(try ArgParser.parseVerify(rest))
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
        case .verify(let options):
            try VerifyRunner.run(options)
        case .version:
            print("simshot \(simshotVersion)")
        case .help(let text):
            print(text)
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
