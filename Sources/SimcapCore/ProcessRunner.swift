import Foundation

public struct ProcessResult {
    public let status: Int32
    public let stdout: String
    public let stderr: String
}

public enum ProcessRunner {
    /// Run an external command with a hard timeout, capturing its output.
    /// The child process is SIGKILLed if it does not exit before the deadline,
    /// which is the main defense against hung simulator/Xcode processes.
    @discardableResult
    public static func run(
        _ executable: String,
        _ args: [String],
        timeout: TimeInterval,
        captureOutput: Bool = true
    ) throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args

        var stdoutData = Data()
        var stderrData = Data()
        let lock = NSLock()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "simcap.pipe.reader", qos: .utility, attributes: .concurrent)

        if captureOutput {
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            queue.async(group: group) {
                let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                lock.lock(); stdoutData.append(data); lock.unlock()
            }
            queue.async(group: group) {
                let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                lock.lock(); stderrData.append(data); lock.unlock()
            }
        } else {
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
        }

        do {
            try process.run()
        } catch {
            throw SimcapError.commandFailed("Failed to launch \(executable): \(error)")
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        var timedOut = false
        if process.isRunning {
            timedOut = true
            process.terminate()
            Thread.sleep(forTimeInterval: 0.2)
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
        }
        process.waitUntilExit()

        if captureOutput {
            group.wait()
        }

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        if timedOut {
            throw SimcapError.timeout("\(executable) \(args.joined(separator: " "))")
        }
        return ProcessResult(status: process.terminationStatus, stdout: stdout, stderr: stderr)
    }
}
