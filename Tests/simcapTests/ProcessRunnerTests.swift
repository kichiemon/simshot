import XCTest
@testable import SimcapCore

final class ProcessRunnerTests: XCTestCase {
    func testSuccessfulRunCapturesOutput() throws {
        let result = try ProcessRunner.run("/bin/echo", ["hello simcap"], timeout: 10)
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "hello simcap")
    }

    func testNonZeroExit() throws {
        let result = try ProcessRunner.run("/bin/sh", ["-c", "echo boom >&2; exit 3"], timeout: 10)
        XCTAssertEqual(result.status, 3)
        XCTAssertTrue(result.stderr.contains("boom"))
    }

    func testTimeoutKillsProcess() {
        XCTAssertThrowsError(
            try ProcessRunner.run("/bin/sleep", ["30"], timeout: 1),
            "expected timeout"
        ) { error in
            guard case SimcapError.timeout = error else {
                return XCTFail("expected .timeout, got \(error)")
            }
        }
    }
}

final class SimulatorRuntimeTests: XCTestCase {
    func testRuntimeComponents() {
        XCTAssertEqual(
            Simulator.runtimeComponents(of: "com.apple.CoreSimulator.SimRuntime.iOS-26-4"),
            [26, 4]
        )
        XCTAssertEqual(
            Simulator.runtimeComponents(of: "com.apple.CoreSimulator.SimRuntime.watchOS-11-0"),
            [11, 0]
        )
        XCTAssertEqual(Simulator.runtimeComponents(of: "unknown"), [])
    }

    func testSlug() {
        let simulator = Simulator(name: "iPhone 17 Pro Max", udid: "ABCD-EF", runtimeComponents: [26, 4])
        XCTAssertEqual(simulator.slug, "iphone-17-pro-max")
        let pad = Simulator(name: "iPad Pro 13-inch (M5)", udid: "X", runtimeComponents: [26, 4])
        XCTAssertEqual(pad.slug, "ipad-pro-13-inch-m5")
    }
}
