import XCTest

@testable import SimshotCore

final class DeviceSpecTests: XCTestCase {
    func testMatchTargetiPhoneSizes() {
        // iPhone 17 Pro Max / 16 Pro Max (6.9")
        XCTAssertEqual(DeviceSpec.matchTarget(width: 1320, height: 2868)?.name, "6.9inch")
        // iPhone 15 Pro Max (6.7")
        XCTAssertEqual(DeviceSpec.matchTarget(width: 1290, height: 2796)?.name, "6.7inch")
        // iPhone Air (6.5")
        XCTAssertEqual(DeviceSpec.matchTarget(width: 1260, height: 2736)?.name, "iphone-air")
        // iPhone 11 Pro Max (6.5")
        XCTAssertEqual(DeviceSpec.matchTarget(width: 1242, height: 2688)?.name, "6.5inch")
        // iPhone 13 Pro Max (6.7")
        XCTAssertEqual(DeviceSpec.matchTarget(width: 1284, height: 2778)?.name, "iphone-13-pro-max")
    }

    func testMatchTargetKeepsCurrentIPhoneNativeSizes() {
        // A native capture that Apple already accepts is a target in its own
        // right, so `--resize` has no reason to upscale it.
        XCTAssertEqual(DeviceSpec.matchTarget(width: 1206, height: 2622)?.name, "6.3inch")
        XCTAssertEqual(DeviceSpec.matchTarget(width: 1179, height: 2556)?.name, "6.1inch")
        XCTAssertEqual(DeviceSpec.matchTarget(width: 1170, height: 2532)?.name, "iphone-14")
        XCTAssertEqual(DeviceSpec.matchTarget(width: 1125, height: 2436)?.name, "iphone-x")
        XCTAssertEqual(DeviceSpec.matchTarget(width: 1242, height: 2208)?.name, "iphone-8-plus")
        XCTAssertEqual(DeviceSpec.matchTarget(width: 750, height: 1334)?.name, "iphone-8")
    }

    func testMatchTargetiPad() {
        // iPad Pro 13-inch (M5)
        let target = DeviceSpec.matchTarget(width: 2064, height: 2752)
        XCTAssertEqual(target?.name, "ipad-pro-13")
        XCTAssertEqual(target?.size.width, 2064)
        XCTAssertEqual(target?.size.height, 2752)
        // iPad Pro 12.9-inch
        XCTAssertEqual(DeviceSpec.matchTarget(width: 2048, height: 2732)?.name, "ipad-pro-12-9")
    }

    func testMatchTargetCoversEveryCurrentIPad11InchSize() {
        // The 11-inch display class has four accepted sizes, and Apple reports
        // them in portrait, so the portrait order must work too.
        XCTAssertEqual(DeviceSpec.matchTarget(width: 1668, height: 2420)?.name, "ipad-11")
        XCTAssertEqual(DeviceSpec.matchTarget(width: 1668, height: 2388)?.name, "ipad-11")
        XCTAssertEqual(DeviceSpec.matchTarget(width: 1488, height: 2266)?.name, "ipad-11")
        XCTAssertEqual(DeviceSpec.matchTarget(width: 2266, height: 1488)?.name, "ipad-11")
        XCTAssertEqual(DeviceSpec.matchTarget(width: 1640, height: 2360)?.name, "ipad-11")
        XCTAssertEqual(DeviceSpec.matchTarget(width: 1668, height: 2224)?.name, "ipad-10-5")
    }

    func testIPad102NativeSizeMapsToTheRequiredIPadSize() {
        // 2160×1620 is the iPad 10.2-inch screen resolution. App Store Connect
        // does not accept it (that display class uploads at 1668×2224), so a raw
        // capture falls through to the 4:3 ratio match and lands on the required
        // 13-inch size instead of being passed through untouched.
        let target = DeviceSpec.matchTarget(width: 2160, height: 1620)
        XCTAssertEqual(target?.name, "ipad-pro-13")
        XCTAssertEqual(target?.size, CGSize(width: 2752, height: 2064))
    }

    func testEveryAcceptedSizeMatchesItself() {
        // `verify` treats a nil match as "App Store Connect would reject this",
        // so every size in the table has to match itself exactly.
        for target in DeviceSpec.appStoreTargets {
            let matched = DeviceSpec.matchTarget(width: Int(target.size.width), height: Int(target.size.height))
            XCTAssertNotNil(
                matched, "\(target.name) \(Int(target.size.width))×\(Int(target.size.height)) did not match")
            XCTAssertEqual(matched?.size, target.size, "\(target.name) matched a different size")
        }
    }

    func testMatchTargetReturnsNilForOddRatio() {
        XCTAssertNil(DeviceSpec.matchTarget(width: 500, height: 500))
    }
}

final class ResizerTests: XCTestCase {
    func makeRGBAImage(width: Int, height: Int) -> CGImage {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 0.5))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    func testHasAlphaAndFlatten() {
        let image = makeRGBAImage(width: 40, height: 60)
        XCTAssertTrue(Resizer.hasAlpha(image))
        let flattened = Resizer.flatten(image)
        XCTAssertFalse(Resizer.hasAlpha(flattened))
        XCTAssertEqual(flattened.width, 40)
        XCTAssertEqual(flattened.height, 60)
    }

    func testResize() {
        let image = makeRGBAImage(width: 100, height: 200)
        let resized = Resizer.resize(image, to: CGSize(width: 50, height: 100))
        XCTAssertEqual(resized.width, 50)
        XCTAssertEqual(resized.height, 100)
        XCTAssertFalse(Resizer.hasAlpha(resized))
    }

    func testWritePNGAndReload() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("simshot-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let url = tempDir.appendingPathComponent("out.png")
        let image = makeRGBAImage(width: 80, height: 160)
        try Resizer.writePNG(image, to: url)

        let reloaded = try Resizer.loadCGImage(at: url)
        XCTAssertEqual(reloaded.width, 80)
        XCTAssertEqual(reloaded.height, 160)
    }

    func testMakeAppStoreImage() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("simshot-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let input = tempDir.appendingPathComponent("input.png")
        try Resizer.writePNG(makeRGBAImage(width: 660, height: 1434), to: input)

        let output = tempDir.appendingPathComponent("output.png")
        let target = DeviceSpec.matchTarget(width: 660, height: 1434)!
        try Resizer.makeAppStoreImage(input: input, output: output, target: target)

        let result = try Resizer.loadCGImage(at: output)
        XCTAssertEqual(result.width, Int(target.size.width))
        XCTAssertEqual(result.height, Int(target.size.height))
        XCTAssertFalse(Resizer.hasAlpha(result))
    }
}
