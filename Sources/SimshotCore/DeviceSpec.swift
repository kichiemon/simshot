import Foundation

/// App Store screenshot size targets and aspect-ratio matching.
public struct AppStoreTarget: Equatable {
    public let size: CGSize
    public let name: String
    public let device: String

    public init(size: CGSize, name: String, device: String) {
        self.size = size
        self.name = name
        self.device = device
    }
}

public enum DeviceSpec {
    /// The App Store screenshot sizes Apple accepts, keyed by device generation.
    /// Aspect-ratio matching picks the right one from a raw simulator capture.
    public static let appStoreTargets: [AppStoreTarget] = [
        AppStoreTarget(size: CGSize(width: 1320, height: 2868), name: "6.9inch", device: "iPhone 16 Pro Max"),
        AppStoreTarget(size: CGSize(width: 1290, height: 2796), name: "6.7inch", device: "iPhone 15 Pro Max"),
        AppStoreTarget(size: CGSize(width: 1242, height: 2688), name: "6.5inch", device: "iPhone 11 Pro Max"),
        AppStoreTarget(size: CGSize(width: 2064, height: 2752), name: "ipad-pro-13", device: "iPad Pro 13-inch"),
        AppStoreTarget(size: CGSize(width: 2048, height: 2732), name: "ipad-pro-12-9", device: "iPad Pro 12.9-inch"),
        AppStoreTarget(size: CGSize(width: 2266, height: 1488), name: "ipad-pro-11", device: "iPad Pro 11-inch"),
        AppStoreTarget(size: CGSize(width: 2160, height: 1620), name: "ipad-10-2", device: "iPad 10.2-inch"),
    ]

    /// Match a raw capture size to the App Store target.
    ///
    /// Strategy:
    /// 1. Exact dimension match (either orientation) — simctl captures are native
    ///    resolution, so this is reliable and disambiguates same-ratio targets
    ///    (e.g. iPad Pro 13" and iPad 10.2" both have a 0.75 aspect ratio).
    /// 2. Otherwise, the closest aspect ratio within 1%.
    public static func matchTarget(width: Int, height: Int) -> AppStoreTarget? {
        let size = CGSize(width: width, height: height)

        for target in appStoreTargets {
            if target.size == size {
                return target
            }
            let flipped = CGSize(width: target.size.height, height: target.size.width)
            if flipped == size {
                return AppStoreTarget(size: size, name: target.name, device: target.device)
            }
        }

        let ratio = Double(width) / Double(height)
        var best: AppStoreTarget?
        var bestDiff = Double.greatestFiniteMagnitude
        for target in appStoreTargets {
            for candidateSize in [target.size, CGSize(width: target.size.height, height: target.size.width)] {
                let diff = abs(ratio - candidateSize.width / candidateSize.height)
                if diff < bestDiff {
                    bestDiff = diff
                    best = AppStoreTarget(size: candidateSize, name: target.name, device: target.device)
                }
            }
        }
        guard let best, bestDiff / ratio < 0.01 else {
            return nil
        }
        return best
    }
}
