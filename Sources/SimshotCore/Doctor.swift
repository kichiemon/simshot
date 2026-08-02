import Foundation

/// Severity of a `simshot doctor` check result.
public enum DoctorStatus: Equatable {
    case ok
    case warn
    case fail
}

/// One `simshot doctor` check result (name, severity, human message).
public struct DoctorCheckResult: Equatable {
    public let name: String
    public let status: DoctorStatus
    public let message: String

    public init(name: String, status: DoctorStatus, message: String) {
        self.name = name
        self.status = status
        self.message = message
    }
}

/// Raw facts gathered from the local machine, passed to `Doctor.evaluate`.
public struct DoctorFacts {
    public let xcodeSelectPath: String?
    public let xcodeVersion: String?
    public let simctlAvailable: Bool
    public let iosRuntimeCount: Int
    public let availableDeviceCount: Int

    public init(
        xcodeSelectPath: String?,
        xcodeVersion: String?,
        simctlAvailable: Bool,
        iosRuntimeCount: Int,
        availableDeviceCount: Int
    ) {
        self.xcodeSelectPath = xcodeSelectPath
        self.xcodeVersion = xcodeVersion
        self.simctlAvailable = simctlAvailable
        self.iosRuntimeCount = iosRuntimeCount
        self.availableDeviceCount = availableDeviceCount
    }
}

/// Environment diagnostics for `simshot doctor`.
///
/// `gather()` probes the local toolchain; `evaluate(_:)` is pure and therefore
/// unit-testable. The CLI prints the results and exits 1 if any check failed.
public enum Doctor {
    /// Collect facts about the local Xcode/simulator environment.
    /// Never throws: every probe failure is captured as a fact.
    public static func gather() -> DoctorFacts {
        let select = try? ProcessRunner.run("/usr/bin/xcode-select", ["-p"], timeout: 15)
        let selectPath =
            (select?.status == 0)
            ? select?.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil
        let selectExists = selectPath.map { FileManager.default.fileExists(atPath: $0) } ?? false

        let build = try? ProcessRunner.run("/usr/bin/xcodebuild", ["-version"], timeout: 30)
        let xcodeVersion =
            (build?.status == 0)
            ? build?.stdout.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n").first.map(
                String.init)
            : nil

        let find = try? ProcessRunner.run("/usr/bin/xcrun", ["--find", "simctl"], timeout: 15)
        let simctlAvailable = find?.status == 0

        let runtimes = try? ProcessRunner.run("/usr/bin/xcrun", ["simctl", "list", "runtimes", "-j"], timeout: 30)
        var runtimeCount = 0
        if let data = runtimes?.stdout.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let list = json["runtimes"] as? [[String: Any]]
        {
            runtimeCount = list.filter { ($0["isAvailable"] as? Bool) ?? false }.count
        }

        let deviceCount = (try? Simulator.listAvailable())?.count ?? 0

        return DoctorFacts(
            xcodeSelectPath: selectExists ? selectPath : nil,
            xcodeVersion: xcodeVersion,
            simctlAvailable: simctlAvailable,
            iosRuntimeCount: runtimeCount,
            availableDeviceCount: deviceCount
        )
    }

    /// Turn facts into check results. Pure logic — no side effects.
    public static func evaluate(_ facts: DoctorFacts) -> [DoctorCheckResult] {
        var results: [DoctorCheckResult] = []

        if let path = facts.xcodeSelectPath {
            results.append(DoctorCheckResult(name: "xcode-select", status: .ok, message: path))
        } else {
            results.append(
                DoctorCheckResult(
                    name: "xcode-select",
                    status: .fail,
                    message:
                        "No Xcode developer directory. Run `xcode-select --install` or `sudo xcode-select -s <path>`."
                )
            )
        }

        if let version = facts.xcodeVersion {
            results.append(DoctorCheckResult(name: "Xcode", status: .ok, message: version))
        } else {
            results.append(
                DoctorCheckResult(
                    name: "Xcode",
                    status: .fail,
                    message: "`xcodebuild -version` failed. Is Xcode fully installed (not just command line tools)?"
                )
            )
        }

        results.append(
            DoctorCheckResult(
                name: "simctl",
                status: facts.simctlAvailable ? .ok : .fail,
                message: facts.simctlAvailable
                    ? "found"
                    : "`xcrun --find simctl` failed. Reinstall Xcode or the command line tools."
            )
        )

        if facts.iosRuntimeCount > 0 {
            results.append(
                DoctorCheckResult(
                    name: "iOS runtimes",
                    status: .ok,
                    message: "\(facts.iosRuntimeCount) installed"
                )
            )
        } else {
            results.append(
                DoctorCheckResult(
                    name: "iOS runtimes",
                    status: .fail,
                    message: "No iOS runtimes installed. Add one in Xcode > Settings > Platforms."
                )
            )
        }

        if facts.availableDeviceCount > 0 {
            results.append(
                DoctorCheckResult(
                    name: "Available simulators",
                    status: .ok,
                    message: "\(facts.availableDeviceCount) available"
                )
            )
        } else {
            results.append(
                DoctorCheckResult(
                    name: "Available simulators",
                    status: .warn,
                    message:
                        "No available devices. Create one with `xcrun simctl create` or in Xcode > Window > Devices and Simulators."
                )
            )
        }

        return results
    }
}
