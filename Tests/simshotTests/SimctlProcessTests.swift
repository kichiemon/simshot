import XCTest

@testable import SimshotCore

final class SimctlProcessTests: XCTestCase {
    override func tearDown() {
        ProcessRunner.handler = ProcessRunner.realRun
        super.tearDown()
    }

    /// Replace the process runner with a fake for the duration of `test`.
    /// Only throws when the `test` closure throws.
    private func withRunner(
        _ replacement: @escaping (String, [String]) -> ProcessResult,
        test: () throws -> Void
    ) rethrows {
        let original = ProcessRunner.handler
        ProcessRunner.handler = { executable, args, _, _ in
            replacement(executable, args)
        }
        defer { ProcessRunner.handler = original }
        try test()
    }

    private static let udidA = "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
    private static let udidB = "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"

    private static func devicesJSON() -> String {
        """
        {
          "devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-26-4": [
              { "name": "iPhone 17 Pro Max", "udid": "\(udidA)", "state": "Shutdown", "isAvailable": true },
              { "name": "iPad Pro 13-inch", "udid": "\(udidB)", "state": "Shutdown", "isAvailable": true },
              { "name": "Unavailable Device", "udid": "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC", "isAvailable": false }
            ],
            "com.apple.CoreSimulator.SimRuntime.watchOS-11-0": [
              { "name": "Apple Watch S11", "udid": "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD", "state": "Shutdown", "isAvailable": true }
            ]
          }
        }
        """
    }

    // MARK: - listAvailable

    func testListAvailableCommandFailure() {
        withRunner { _, _ in
            ProcessResult(status: 1, stdout: "", stderr: "Unable to find simctl")
        } test: {
            assertThrows(.commandFailed) {
                try Simulator.listAvailable()
            } messageContains: {
                $0.contains("simctl list devices")
            }
        }
    }

    func testListAvailableMalformedJSON() {
        withRunner { _, _ in
            ProcessResult(status: 0, stdout: "not json", stderr: "")
        } test: {
            assertThrows(.invalid) {
                try Simulator.listAvailable()
            } messageContains: {
                $0.contains("simctl list devices")
            }
        }
    }

    func testListAvailableParsesAndFiltersUnavailable() throws {
        try withRunner { _, _ in
            ProcessResult(status: 0, stdout: Self.devicesJSON(), stderr: "")
        } test: {
            let devices = try Simulator.listAvailable()
            XCTAssertEqual(devices.count, 3)
            XCTAssertTrue(devices.allSatisfy { !$0.name.contains("Unavailable") })
            XCTAssertEqual(devices.first(where: { $0.name == "iPhone 17 Pro Max" })?.udid, Self.udidA)
        }
    }

    // MARK: - resolve

    func testResolveByUDIDExact() throws {
        try withRunner { _, _ in
            ProcessResult(status: 0, stdout: Self.devicesJSON(), stderr: "")
        } test: {
            let resolved = try Simulator.resolve(Self.udidB.lowercased())
            XCTAssertEqual(resolved.udid, Self.udidB)
            XCTAssertEqual(resolved.name, "iPad Pro 13-inch")
        }
    }

    func testResolveByUDIDNotFound() {
        withRunner { _, _ in
            ProcessResult(status: 0, stdout: Self.devicesJSON(), stderr: "")
        } test: {
            assertThrows(.notFound) {
                try Simulator.resolve("FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")
            } messageContains: {
                $0.contains("UDID")
            }
        }
    }

    func testResolveByNameSubstring() throws {
        try withRunner { _, _ in
            ProcessResult(status: 0, stdout: Self.devicesJSON(), stderr: "")
        } test: {
            let resolved = try Simulator.resolve("iphone-17-pro-max")
            XCTAssertEqual(resolved.name, "iPhone 17 Pro Max")
        }
    }

    func testResolveNoMatch() {
        withRunner { _, _ in
            ProcessResult(status: 0, stdout: Self.devicesJSON(), stderr: "")
        } test: {
            assertThrows(.notFound) {
                try Simulator.resolve("nope")
            } messageContains: {
                $0.contains("nope")
            }
        }
    }

    func testResolveNewestRuntimeWins() throws {
        let json = """
            {
              "devices": {
                "com.apple.CoreSimulator.SimRuntime.iOS-26-4": [
                  { "name": "iPhone 16", "udid": "\(Self.udidA)", "isAvailable": true }
                ],
                "com.apple.CoreSimulator.SimRuntime.iOS-26-5": [
                  { "name": "iPhone 16", "udid": "\(Self.udidB)", "isAvailable": true }
                ]
              }
            }
            """
        try withRunner { _, _ in
            ProcessResult(status: 0, stdout: json, stderr: "")
        } test: {
            let resolved = try Simulator.resolve("iphone-16")
            XCTAssertEqual(resolved.udid, Self.udidB, "newest runtime should win")
        }
    }

    func testResolveAmbiguousNamesThrows() {
        let json = """
            {
              "devices": {
                "com.apple.CoreSimulator.SimRuntime.iOS-26-4": [
                  { "name": "iPhone 16", "udid": "\(Self.udidA)", "isAvailable": true },
                  { "name": "iPhone 16 Pro", "udid": "\(Self.udidB)", "isAvailable": true }
                ]
              }
            }
            """
        withRunner { _, _ in
            ProcessResult(status: 0, stdout: json, stderr: "")
        } test: {
            // "iphone-16" matches both "iPhone 16" and "iPhone 16 Pro".
            assertThrows(.invalid) {
                try Simulator.resolve("iphone-16")
            } messageContains: {
                $0.contains("multiple")
            }
        }
    }

    // MARK: - simctl operations

    func testBootFailure() {
        let sim = Simulator(name: "iPhone 17 Pro Max", udid: Self.udidA, runtimeComponents: [26, 4])
        withRunner { _, _ in
            ProcessResult(status: 1, stdout: "", stderr: "core device failed")
        } test: {
            assertThrows(.commandFailed) {
                try sim.boot()
            } messageContains: {
                $0.contains("bootstatus")
            }
        }
    }

    func testOverrideStatusBarFailure() {
        let sim = Simulator(name: "iPhone 17 Pro Max", udid: Self.udidA, runtimeComponents: [26, 4])
        withRunner { _, _ in
            ProcessResult(status: 1, stdout: "", stderr: "no device")
        } test: {
            assertThrows(.commandFailed) {
                try sim.overrideStatusBar()
            } messageContains: {
                $0.contains("status_bar")
            }
        }
    }

    func testInstallAppFailureAfterRetries() {
        let sim = Simulator(name: "iPhone 17 Pro Max", udid: Self.udidA, runtimeComponents: [26, 4])
        var calls = 0
        withRunner { _, _ in
            calls += 1
            return ProcessResult(status: 1, stdout: "", stderr: "install timeout")
        } test: {
            assertThrows(.commandFailed) {
                try sim.installApp(URL(fileURLWithPath: "/tmp/MyApp.app"))
            } messageContains: {
                $0.contains("install")
            }
            XCTAssertEqual(calls, 2, "install should retry once")
        }
    }

    func testLaunchFailureAfterRetries() throws {
        let sim = Simulator(name: "iPhone 17 Pro Max", udid: Self.udidA, runtimeComponents: [26, 4])
        var calls = 0
        try withRunner { _, _ in
            calls += 1
            return ProcessResult(status: 1, stdout: "", stderr: "launch failed")
        } test: {
            assertThrows(.commandFailed) {
                try sim.launch(bundleID: "com.example.myapp", arguments: ["--screenshot-scene", "home"])
            } messageContains: {
                $0.contains("launch")
            }
            XCTAssertEqual(calls, 2, "launch should retry once")
        }
    }

    func testLaunchPassesArgumentsToSimctl() throws {
        let sim = Simulator(name: "iPhone 17 Pro Max", udid: Self.udidA, runtimeComponents: [26, 4])
        var captured: [String] = []
        try withRunner { _, args in
            captured = args
            return ProcessResult(status: 0, stdout: "launched", stderr: "")
        } test: {
            try sim.launch(
                bundleID: "com.example.myapp",
                arguments: ["-AppleLanguages", "(ja)", "--screenshot-scene", "detail"]
            )
        }
        XCTAssertEqual(captured.prefix(4), ["simctl", "launch", Self.udidA, "com.example.myapp"])
        XCTAssertTrue(captured.contains("--screenshot-scene"))
        XCTAssertTrue(captured.contains("detail"))
    }

    func testScreenshotFailureAfterRetries() throws {
        let sim = Simulator(name: "iPhone 17 Pro Max", udid: Self.udidA, runtimeComponents: [26, 4])
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("simshot-simctl-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var calls = 0
        try withRunner { _, _ in
            calls += 1
            return ProcessResult(status: 1, stdout: "", stderr: "screenshot failed")
        } test: {
            assertThrows(.commandFailed) {
                try sim.screenshot(to: tempDir.appendingPathComponent("01_home.png"))
            } messageContains: {
                $0.contains("screenshot")
            }
            XCTAssertEqual(calls, 3, "screenshot should retry twice")
        }
    }

    // MARK: - Helpers

    private enum ErrorKind: String {
        case usage, commandFailed, timeout, notFound, invalid
    }

    private func assertThrows(
        _ kind: ErrorKind,
        _ body: () throws -> Void,
        messageContains predicate: (String) -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try body(), file: file, line: line) { error in
            guard matches(kind, error) else {
                return XCTFail("expected \(kind), got \(error)", file: file, line: line)
            }
            XCTAssertTrue(
                predicate(String(describing: error)), "unexpected message: \(error)", file: file,
                line: line)
        }
    }

    private func matches(_ kind: ErrorKind, _ error: Error) -> Bool {
        guard let actual = error as? SimshotError else { return false }
        switch (kind, actual) {
        case (.usage, .usage), (.commandFailed, .commandFailed), (.timeout, .timeout), (.notFound, .notFound),
            (.invalid, .invalid):
            return true
        default:
            return false
        }
    }
}
