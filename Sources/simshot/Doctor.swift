import Foundation
import SimshotCore

enum DoctorRunner {
    static func run() throws {
        let results = Doctor.evaluate(Doctor.gather())
        var hasFailure = false
        for result in results {
            switch result.status {
            case .ok:
                print("✅ \(result.name): \(result.message)")
            case .warn:
                print("⚠️  \(result.name): \(result.message)")
            case .fail:
                print("❌ \(result.name): \(result.message)")
                hasFailure = true
            }
        }
        print("")
        if hasFailure {
            Log.error("❌ Doctor found problems. Fix them before running `simshot shoot`.")
            exit(1)
        }
        print("✅ All checks passed.")
    }
}
