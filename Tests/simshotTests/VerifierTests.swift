import CoreGraphics
import XCTest

@testable import SimshotCore

final class VerifierTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("simshot-verify-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let root, FileManager.default.fileExists(atPath: root.path) {
            try? FileManager.default.removeItem(at: root)
        }
    }

    // MARK: - Helpers

    private func makeFolder(_ device: String, _ language: String) throws -> URL {
        let folder = root.appendingPathComponent(device).appendingPathComponent(language)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func writePNG(
        width: Int,
        height: Int,
        alpha: Bool,
        named name: String,
        in folder: URL
    ) throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let info: CGImageAlphaInfo = alpha ? .premultipliedLast : .noneSkipLast
        let context = try XCTUnwrap(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: space,
                bitmapInfo: info.rawValue
            ))
        context.setFillColor(CGColor(srgbRed: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try XCTUnwrap(context.makeImage())
        try Resizer.writePNG(image, to: folder.appendingPathComponent(name))
    }

    private func kinds(_ report: VerifyReport) -> [VerifyIssue.Kind] {
        report.issues.map(\.kind)
    }

    // MARK: - Happy path

    func testAppStoreReadyTreeHasNoIssues() throws {
        let folder = try makeFolder("iphone-17-pro-max", "ja")
        try writePNG(width: 1290, height: 2796, alpha: false, named: "01_home.png", in: folder)
        try writePNG(width: 1290, height: 2796, alpha: false, named: "02_detail.png", in: folder)

        let report = Verifier.verify(root: root)

        XCTAssertTrue(report.ok, "expected a clean tree, got \(report.issues)")
        XCTAssertEqual(report.checkedFiles, 2)
        XCTAssertEqual(report.folders.count, 1)
        XCTAssertEqual(report.folders.first?.target?.name, "6.7inch")
        XCTAssertEqual(report.folders.first?.size, CGSize(width: 1290, height: 2796))
    }

    func testLandscapeIPadSizeIsAccepted() throws {
        let folder = try makeFolder("ipad-pro-13", "en")
        try writePNG(width: 2752, height: 2064, alpha: false, named: "01_home.png", in: folder)

        let report = Verifier.verify(root: root)

        XCTAssertTrue(report.ok, "landscape iPad capture should pass, got \(report.issues)")
    }

    // MARK: - Size problems

    func testAlphaChannelIsReported() throws {
        let folder = try makeFolder("iphone-17-pro-max", "en")
        try writePNG(width: 1290, height: 2796, alpha: true, named: "01_home.png", in: folder)

        let report = Verifier.verify(root: root)

        XCTAssertEqual(kinds(report), [.alphaChannel])
        XCTAssertTrue(report.issues[0].fix.contains("--resize"))
    }

    func testNearMissSizeIsReportedAsWrongSize() throws {
        let folder = try makeFolder("iphone-17-pro-max", "en")
        // 1280×2760 is two pixels off 1284×2778 (the same 6.7" display class), a
        // shape App Store Connect rejects.
        try writePNG(width: 1280, height: 2760, alpha: false, named: "01_home.png", in: folder)

        let report = Verifier.verify(root: root)

        XCTAssertEqual(kinds(report), [.wrongSize])
        // The hint names the closest accepted size; what matters is that the
        // reported dimensions are the ones actually on disk.
        XCTAssertTrue(report.issues[0].message.contains("but got 1280×2760"), report.issues[0].message)
        XCTAssertTrue(report.issues[0].fix.contains("--resize"))
    }

    func testNativeSizesAppleAcceptsPass() throws {
        // These are native simulator captures, not resized output. Apple accepts
        // every one of them, so verify must not ask for a resize.
        for (device, size) in [
            ("iphone-17", CGSize(width: 1179, height: 2556)),
            ("iphone-17-pro", CGSize(width: 1206, height: 2622)),
            ("ipad-air-11", CGSize(width: 1640, height: 2360)),
            ("ipad-pro-11", CGSize(width: 1668, height: 2388)),
            ("ipad-pro-11-m4", CGSize(width: 1668, height: 2420)),
            ("ipad-9th", CGSize(width: 1536, height: 2048)),
            ("iphone-se", CGSize(width: 750, height: 1334)),
        ] {
            let folder = try makeFolder(device, "en")
            try writePNG(
                width: Int(size.width), height: Int(size.height), alpha: false, named: "01_home.png", in: folder)
        }

        let report = Verifier.verify(root: root)

        XCTAssertTrue(report.ok, "unexpected issues: \(report.issues)")
        XCTAssertEqual(report.checkedFiles, 7)
    }

    func testIPad102NativeSizeIsReported() throws {
        // 2160×1620 is the iPad 10.2-inch screen resolution. App Store Connect
        // uploads that display class at 1668×2224, so the raw capture is not
        // publishable as-is.
        let folder = try makeFolder("ipad-10-2", "en")
        try writePNG(width: 2160, height: 1620, alpha: false, named: "01_home.png", in: folder)

        let report = Verifier.verify(root: root)

        XCTAssertEqual(kinds(report), [.wrongSize])
        XCTAssertTrue(report.issues[0].message.contains("but got 2160×1620"), report.issues[0].message)
    }

    func testNonScreenshotAspectIsReported() throws {
        let folder = try makeFolder("iphone-17-pro-max", "en")
        try writePNG(width: 1000, height: 1000, alpha: false, named: "01_home.png", in: folder)

        let report = Verifier.verify(root: root)

        XCTAssertEqual(kinds(report), [.notAppStoreSize])
        XCTAssertEqual(report.folders.first?.size, nil, "a rejected file must not be treated as the folder size")
    }

    func testMixedSizesInOneFolderAreReported() throws {
        let folder = try makeFolder("iphone-17-pro-max", "en")
        try writePNG(width: 1290, height: 2796, alpha: false, named: "01_home.png", in: folder)
        try writePNG(width: 1320, height: 2868, alpha: false, named: "02_detail.png", in: folder)

        let report = Verifier.verify(root: root)

        XCTAssertEqual(kinds(report), [.inconsistentSize])
        XCTAssertTrue(report.issues[0].path.hasSuffix("02_detail.png"))
    }

    // MARK: - Missing / empty

    func testEmptyFolderIsReported() throws {
        _ = try makeFolder("iphone-17-pro-max", "ja")

        let report = Verifier.verify(root: root)

        XCTAssertEqual(kinds(report), [.emptyDirectory])
        XCTAssertEqual(report.checkedFiles, 0)
        // Empty folders still show up in the report, with no agreed size.
        XCTAssertEqual(report.folders.map(\.path), ["iphone-17-pro-max/ja"])
        XCTAssertEqual(report.folders.first?.fileCount, 0)
        XCTAssertNil(report.folders.first?.size)
    }

    func testRequestedDeviceThatIsMissingIsReported() throws {
        let folder = try makeFolder("iphone-17-pro-max", "ja")
        try writePNG(width: 1290, height: 2796, alpha: false, named: "01_home.png", in: folder)

        let report = Verifier.verify(root: root, devices: ["iphone-17-pro-max", "ipad-pro-13"])

        XCTAssertEqual(kinds(report), [.missingDirectory])
        XCTAssertEqual(report.issues[0].message, "no screenshots captured for device 'ipad-pro-13'")
    }

    func testRequestedLanguageThatIsMissingIsReported() throws {
        let folder = try makeFolder("iphone-17-pro-max", "ja")
        try writePNG(width: 1290, height: 2796, alpha: false, named: "01_home.png", in: folder)

        let report = Verifier.verify(root: root, languages: ["ja", "en"])

        XCTAssertEqual(kinds(report), [.missingDirectory])
        XCTAssertEqual(report.issues[0].path, "iphone-17-pro-max/en")
    }

    func testMissingRootIsReportedOnce() throws {
        let missing = root.appendingPathComponent("nope")

        let report = Verifier.verify(root: missing)

        XCTAssertEqual(kinds(report), [.missingDirectory])
        XCTAssertEqual(report.folders.count, 0)
    }

    // MARK: - raw/ handling

    func testRawDirectoryIsSkippedAndReported() throws {
        let folder = try makeFolder("iphone-17-pro-max", "ja")
        try writePNG(width: 1290, height: 2796, alpha: false, named: "01_home.png", in: folder)

        // Raw simctl captures are unflattened and at native resolution — they
        // must never be counted as App Store copies.
        let raw = try makeFolder("raw", "ja")
        try writePNG(width: 1206, height: 2622, alpha: true, named: "01_home.png", in: raw)

        let report = Verifier.verify(root: root)

        XCTAssertTrue(report.ok, "raw/ must not produce issues, got \(report.issues)")
        XCTAssertEqual(report.skipped, ["raw"])
        XCTAssertEqual(report.checkedFiles, 1)
        XCTAssertEqual(report.folders.map(\.path), ["iphone-17-pro-max/ja"])
    }

    func testRawIsStillReportedWhenDevicesAreExplicit() throws {
        let folder = try makeFolder("iphone-17-pro-max", "ja")
        try writePNG(width: 1290, height: 2796, alpha: false, named: "01_home.png", in: folder)
        let raw = try makeFolder("raw", "ja")
        try writePNG(width: 1206, height: 2622, alpha: true, named: "01_home.png", in: raw)

        let report = Verifier.verify(root: root, devices: ["iphone-17-pro-max"])

        XCTAssertEqual(report.skipped, ["raw"], "raw/ must be reported even when --devices filters the scan")
        XCTAssertTrue(report.ok, "unexpected issues: \(report.issues)")
    }

    // MARK: - Multiple devices

    func testMultipleDevicesAndLanguages() throws {
        for (device, size) in [
            ("iphone-17-pro-max", CGSize(width: 1290, height: 2796)),
            ("ipad-pro-13", CGSize(width: 2064, height: 2752)),
        ] {
            for language in ["ja", "en"] {
                let folder = try makeFolder(device, language)
                try writePNG(
                    width: Int(size.width), height: Int(size.height), alpha: false,
                    named: "01_home.png", in: folder)
            }
        }

        let report = Verifier.verify(
            root: root, devices: ["iphone-17-pro-max", "ipad-pro-13"], languages: ["ja", "en"])

        XCTAssertTrue(report.ok, "unexpected issues: \(report.issues)")
        XCTAssertEqual(report.folders.count, 4)
        XCTAssertEqual(report.checkedFiles, 4)
    }
}
