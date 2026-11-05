import XCTest

@testable import SimshotCore

final class DoctorTests: XCTestCase {
    func testHealthyEnvironmentAllPass() {
        let facts = DoctorFacts(
            xcodeSelectPath: "/Applications/Xcode.app/Contents/Developer",
            xcodeVersion: "Xcode 26.4",
            simctlAvailable: true,
            iosRuntimeCount: 3,
            availableDeviceCount: 5
        )
        let results = Doctor.evaluate(facts)
        XCTAssertEqual(results.count, 5)
        XCTAssertTrue(results.allSatisfy { $0.status == .ok }, "all checks should pass: \(results)")
    }

    func testMissingToolchainFails() {
        let facts = DoctorFacts(
            xcodeSelectPath: nil,
            xcodeVersion: nil,
            simctlAvailable: false,
            iosRuntimeCount: 0,
            availableDeviceCount: 0
        )
        let results = Doctor.evaluate(facts)
        XCTAssertEqual(results.first(where: { $0.name == "xcode-select" })?.status, .fail)
        XCTAssertEqual(results.first(where: { $0.name == "Xcode" })?.status, .fail)
        XCTAssertEqual(results.first(where: { $0.name == "simctl" })?.status, .fail)
        XCTAssertEqual(results.first(where: { $0.name == "iOS runtimes" })?.status, .fail)
    }

    func testNoRuntimesFailsEvenWithDevices() {
        let facts = DoctorFacts(
            xcodeSelectPath: "/x",
            xcodeVersion: "Xcode 26.4",
            simctlAvailable: true,
            iosRuntimeCount: 0,
            availableDeviceCount: 2
        )
        let results = Doctor.evaluate(facts)
        XCTAssertEqual(results.first(where: { $0.name == "iOS runtimes" })?.status, .fail)
        XCTAssertEqual(results.first(where: { $0.name == "Available simulators" })?.status, .ok)
    }

    func testNoDevicesIsWarningNotFailure() {
        let facts = DoctorFacts(
            xcodeSelectPath: "/x",
            xcodeVersion: "Xcode 26.4",
            simctlAvailable: true,
            iosRuntimeCount: 1,
            availableDeviceCount: 0
        )
        let results = Doctor.evaluate(facts)
        XCTAssertEqual(results.first(where: { $0.name == "Available simulators" })?.status, .warn)
        XCTAssertTrue(results.contains { $0.status == .fail } == false)
    }

    func testSimctlMissingFails() {
        let facts = DoctorFacts(
            xcodeSelectPath: "/x",
            xcodeVersion: "Xcode 26.4",
            simctlAvailable: false,
            iosRuntimeCount: 1,
            availableDeviceCount: 1
        )
        let results = Doctor.evaluate(facts)
        XCTAssertEqual(results.first(where: { $0.name == "simctl" })?.status, .fail)
    }

    func testAlwaysReturnsAllFiveChecks() {
        let facts = DoctorFacts(
            xcodeSelectPath: nil,
            xcodeVersion: nil,
            simctlAvailable: false,
            iosRuntimeCount: 0,
            availableDeviceCount: 0
        )
        let results = Doctor.evaluate(facts)
        XCTAssertEqual(results.count, 5)
        XCTAssertEqual(
            Set(results.map { $0.name }),
            ["xcode-select", "Xcode", "simctl", "iOS runtimes", "Available simulators"]
        )
    }

    func testFailureMessagesAreActionable() {
        let facts = DoctorFacts(
            xcodeSelectPath: nil,
            xcodeVersion: nil,
            simctlAvailable: false,
            iosRuntimeCount: 0,
            availableDeviceCount: 0
        )
        for result in Doctor.evaluate(facts) {
            XCTAssertFalse(result.message.isEmpty, "\(result.name) message should not be empty")
            if result.status == .fail {
                XCTAssertTrue(
                    result.message.lowercased().contains("`") || result.message.lowercased().contains("xcode"),
                    "\(result.name) failure message should hint at a fix: \(result.message)"
                )
            }
        }
    }

    func testXcodeOnlyCheckFailsIndependently() {
        let facts = DoctorFacts(
            xcodeSelectPath: "/Applications/Xcode.app/Contents/Developer",
            xcodeVersion: nil,
            simctlAvailable: true,
            iosRuntimeCount: 2,
            availableDeviceCount: 3
        )
        let results = Doctor.evaluate(facts)
        XCTAssertEqual(results.first(where: { $0.name == "xcode-select" })?.status, .ok)
        XCTAssertEqual(results.first(where: { $0.name == "Xcode" })?.status, .fail)
        XCTAssertEqual(results.first(where: { $0.name == "simctl" })?.status, .ok)
    }

    // MARK: - iOS runtime counting

    func testIosRuntimeCountFiltersNonIOSPlatforms() {
        let runtimes: [[String: Any]] = [
            ["name": "iOS 27.2", "platform": "iOS", "isAvailable": true],
            ["name": "watchOS 11.0", "platform": "watchOS", "isAvailable": true],
            ["name": "tvOS 18.0", "platform": "tvOS", "isAvailable": true],
            ["name": "visionOS 2.0", "platform": "visionOS", "isAvailable": true],
            ["name": "iOS 26.4", "platform": "iOS", "isAvailable": false],
        ]
        XCTAssertEqual(Doctor.iosRuntimeCount(from: runtimes), 1)
    }

    func testIosRuntimeCountFallsBackToNameWhenPlatformMissing() {
        let runtimes: [[String: Any]] = [
            ["name": "iOS 26.4", "isAvailable": true],
            ["name": "watchOS 11.0", "isAvailable": true],
        ]
        XCTAssertEqual(Doctor.iosRuntimeCount(from: runtimes), 1)
    }

    func testIosRuntimeCountFallsBackToIdentifier() {
        let runtimes: [[String: Any]] = [
            ["name": "Some Runtime", "identifier": "com.apple.CoreSimulator.SimRuntime.iOS-26-4", "isAvailable": true]
        ]
        XCTAssertEqual(Doctor.iosRuntimeCount(from: runtimes), 1)
    }

    func testIosRuntimeCountEmpty() {
        XCTAssertEqual(Doctor.iosRuntimeCount(from: []), 0)
    }

}
