import Foundation
import SimshotCore

enum InitRunner {
    /// Write a commented `simshot.yml` scaffold. Interactive unless `--yes`.
    static func run(yes: Bool, output: String) throws {
        let answers: InitConfig.Answers
        if yes {
            answers = .defaults
        } else {
            answers = prompt()
        }

        let url = URL(fileURLWithPath: output)
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw SimshotError.usage("\(output) already exists — remove it or pass --output <path>.")
        }
        try InitConfig.template(answers: answers).write(to: url, atomically: true, encoding: .utf8)
        Log.info("✅ Wrote \(output)")
        Log.info("   Edit it, then run `simshot shoot` with the values it documents.")
    }

    // MARK: - Interactive prompts

    private static func prompt() -> InitConfig.Answers {
        var answers = InitConfig.Answers.defaults
        answers.bundleID = ask("Bundle ID", default: answers.bundleID)
        answers.project = askOptional("Xcode project path", default: answers.project)
        answers.scheme = askOptional("Scheme", default: answers.scheme)
        answers.devices = askCSV("Simulators (comma-separated)", default: answers.devices)
        answers.languages = askCSV("Languages (comma-separated)", default: answers.languages)
        answers.scenes = askCSV("Scenes (comma-separated)", default: answers.scenes)
        answers.output = ask("Output directory", default: answers.output)
        answers.resize = askBool("Write resized App Store copies?", default: answers.resize)
        return answers
    }

    private static func ask(_ label: String, default value: String) -> String {
        print("\(label) [\(value)]: ", terminator: "")
        guard
            let input = readLine(strippingNewline: true)?
                .trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty
        else {
            return value
        }
        return input
    }

    private static func askOptional(_ label: String, default value: String?) -> String? {
        let current = value ?? ""
        print("\(label) [\(current)]: ", terminator: "")
        guard
            let input = readLine(strippingNewline: true)?
                .trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty
        else {
            return value
        }
        return input
    }

    private static func askCSV(_ label: String, default value: [String]) -> [String] {
        print("\(label) [\(value.joined(separator: ","))]: ", terminator: "")
        guard
            let input = readLine(strippingNewline: true)?
                .trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty
        else {
            return value
        }
        return input.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func askBool(_ label: String, default value: Bool) -> Bool {
        print("\(label) [\(value ? "y" : "n")]: ", terminator: "")
        guard
            let input = readLine(strippingNewline: true)?
                .trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !input.isEmpty
        else {
            return value
        }
        return ["y", "yes"].contains(input)
    }
}
