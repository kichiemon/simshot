import Foundation

/// A single App Store screenshot size target (device + name + dimensions).
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
    /// The screenshot sizes App Store Connect accepts for iPhone and iPad, from
    /// Apple's "Screenshot specifications" reference
    /// (developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).
    ///
    /// One table drives both jobs: `--resize` picks a target out of it, and
    /// `verify` asks whether a file on disk sits on one of these sizes. So it
    /// has to list what Apple accepts, not only what simshot would write. A
    /// capture that is already an accepted size (an iPad Air's 1640×2360, an
    /// iPhone 17's 1179×2556) keeps its own resolution instead of being scaled
    /// to a neighbouring size.
    ///
    /// Apple lists most sizes in both orientations; those are one row here and
    /// `matchTarget` flips them. The iPhone SE (1st gen) and iPhone 4 entries
    /// exist because Apple accepts screenshots with and without the status bar,
    /// which are different pixel sizes. Sizes for the unreleased iPhone Duo are
    /// left out.
    ///
    /// Order matters: `matchTarget` breaks an aspect-ratio tie by first match,
    /// so the preferred sizes (largest iPhone, iPad 13") come first.
    public static let appStoreTargets: [AppStoreTarget] = [
        // iPhone — Dynamic Island (large display)
        AppStoreTarget(
            size: CGSize(width: 1320, height: 2868), name: "6.9inch", device: "iPhone 16 Pro Max / 17 Pro Max"),
        AppStoreTarget(
            size: CGSize(width: 1290, height: 2796), name: "6.7inch", device: "iPhone 14 Pro Max / 15 Plus / 16 Plus"),
        AppStoreTarget(size: CGSize(width: 1260, height: 2736), name: "iphone-air", device: "iPhone Air"),

        // iPhone — Face ID (large display)
        AppStoreTarget(
            size: CGSize(width: 1284, height: 2778), name: "iphone-13-pro-max", device: "iPhone 12 Pro Max / 13 Pro Max"
        ),
        AppStoreTarget(size: CGSize(width: 1242, height: 2688), name: "6.5inch", device: "iPhone 11 Pro Max / XS Max"),

        // iPhone — Dynamic Island (medium display)
        AppStoreTarget(size: CGSize(width: 1206, height: 2622), name: "6.3inch", device: "iPhone 16 Pro / 17 Pro"),
        AppStoreTarget(
            size: CGSize(width: 1179, height: 2556), name: "6.1inch", device: "iPhone 15 / 16 / 17 / 15 Pro / 16 Pro"),

        // iPhone — Face ID (medium display)
        AppStoreTarget(size: CGSize(width: 1170, height: 2532), name: "iphone-14", device: "iPhone 12 / 13 / 14"),
        AppStoreTarget(size: CGSize(width: 1125, height: 2436), name: "iphone-x", device: "iPhone X / XS / 11 Pro"),
        AppStoreTarget(size: CGSize(width: 1080, height: 2340), name: "iphone-12-mini", device: "iPhone 12 mini"),

        // iPhone — Home button
        AppStoreTarget(
            size: CGSize(width: 1242, height: 2208), name: "iphone-8-plus", device: "iPhone 6 Plus / 8 Plus"),
        AppStoreTarget(
            size: CGSize(width: 750, height: 1334), name: "iphone-8", device: "iPhone 8 / SE (2nd, 3rd gen)"),

        // iPhone — Home button, 4-inch display (status bar changes the height)
        AppStoreTarget(
            size: CGSize(width: 640, height: 1136), name: "iphone-se-1", device: "iPhone SE (1st gen), with status bar"),
        AppStoreTarget(
            size: CGSize(width: 640, height: 1096), name: "iphone-se-1", device: "iPhone SE (1st gen), no status bar"),
        AppStoreTarget(
            size: CGSize(width: 1136, height: 640), name: "iphone-se-1", device: "iPhone SE (1st gen), landscape"),
        AppStoreTarget(
            size: CGSize(width: 1136, height: 600), name: "iphone-se-1", device: "iPhone SE (1st gen), landscape"),

        // iPhone — Home button, 3.5-inch display
        AppStoreTarget(
            size: CGSize(width: 640, height: 960), name: "iphone-4", device: "iPhone 4 / 4S, with status bar"),
        AppStoreTarget(size: CGSize(width: 640, height: 920), name: "iphone-4", device: "iPhone 4 / 4S, no status bar"),
        AppStoreTarget(size: CGSize(width: 960, height: 640), name: "iphone-4", device: "iPhone 4 / 4S, landscape"),
        AppStoreTarget(size: CGSize(width: 960, height: 600), name: "iphone-4", device: "iPhone 4 / 4S, landscape"),

        // iPad — 13-inch display (required for iPad apps)
        AppStoreTarget(
            size: CGSize(width: 2064, height: 2752), name: "ipad-pro-13", device: "iPad Pro 13-inch / iPad Air 13-inch"),

        // iPad — 12.9-inch display
        AppStoreTarget(
            size: CGSize(width: 2048, height: 2732), name: "ipad-pro-12-9", device: "iPad Pro 12.9-inch (2nd gen)"),

        // iPad — 11-inch display
        AppStoreTarget(
            size: CGSize(width: 1668, height: 2420), name: "ipad-11", device: "iPad Pro 11-inch (M4, M5)"),
        AppStoreTarget(
            size: CGSize(width: 1668, height: 2388), name: "ipad-11",
            device: "iPad Pro 11-inch (2018-2022)"),
        AppStoreTarget(
            size: CGSize(width: 2266, height: 1488), name: "ipad-11", device: "iPad mini (6th gen / A17 Pro)"),
        AppStoreTarget(
            size: CGSize(width: 1640, height: 2360), name: "ipad-11",
            device: "iPad Air 11-inch / iPad (10th gen, A16)"),

        // iPad — 10.5-inch display
        AppStoreTarget(
            size: CGSize(width: 1668, height: 2224), name: "ipad-10-5", device: "iPad Pro 10.5-inch / iPad (9th gen)"),

        // iPad — 9.7-inch display (status bar changes the height)
        AppStoreTarget(
            size: CGSize(width: 1536, height: 2048), name: "ipad-9-7", device: "iPad 9.7-inch, with status bar"),
        AppStoreTarget(
            size: CGSize(width: 1536, height: 2008), name: "ipad-9-7", device: "iPad 9.7-inch, no status bar"),
        AppStoreTarget(size: CGSize(width: 2048, height: 1536), name: "ipad-9-7", device: "iPad 9.7-inch, landscape"),
        AppStoreTarget(size: CGSize(width: 2048, height: 1496), name: "ipad-9-7", device: "iPad 9.7-inch, landscape"),

        // iPad — 7.9-inch display (status bar changes the height)
        AppStoreTarget(size: CGSize(width: 768, height: 1024), name: "ipad-mini", device: "iPad mini, with status bar"),
        AppStoreTarget(size: CGSize(width: 768, height: 1004), name: "ipad-mini", device: "iPad mini, no status bar"),
        AppStoreTarget(size: CGSize(width: 1024, height: 768), name: "ipad-mini", device: "iPad mini, landscape"),
        AppStoreTarget(size: CGSize(width: 1024, height: 748), name: "ipad-mini", device: "iPad mini, landscape"),
    ]

    /// Match a raw capture size to an App Store target.
    ///
    /// Strategy:
    /// 1. Exact dimension match (either orientation) — simctl captures are native
    ///    resolution, so this is reliable and disambiguates same-ratio targets
    ///    (e.g. the 4:3 iPads, and the iPad 10.2" raw size that Apple rejects).
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
