import XCTest

@testable import SimshotCore

final class DeviceSpecTests: XCTestCase {
    func testMatchTargetiPhoneProMaxSizes() {
        // iPhone 17 Pro Max / 16 Pro Max (6.9")
        XCTAssertEqual(DeviceSpec.matchTarget(width: 1320, height: 2868)?.name, "6.9inch")
        // iPhone 15 Pro Max (6.7")
        XCTAssertEqual(DeviceSpec.matchTarget(width: 1290, height: 2796)?.name, "6.7inch")
        // iPhone 11 Pro Max (6.5")
        XCTAssertEqual(DeviceSpec.matchTarget(width: 1242, height: 2688)?.name, "6.5inch")
    }

    func testMatchTargetiPad() {
        // iPad Pro 13-inch (M5)
        let target = DeviceSpec.matchTarget(width: 2064, height: 2752)
        XCTAssertEqual(target?.name, "ipad-pro-13")
        XCTAssertEqual(target?.size.width, 2064)
        XCTAssertEqual(target?.size.height, 2752)
        // iPad 10.2-inch, both portrait and landscape
        XCTAssertEqual(DeviceSpec.matchTarget(width: 1620, height: 2160)?.name, "ipad-10-2")
        XCTAssertEqual(DeviceSpec.matchTarget(width: 2160, height: 1620)?.name, "ipad-10-2")
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
