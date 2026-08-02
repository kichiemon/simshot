import CoreGraphics
import XCTest

@testable import SimshotCore

final class ResizerFailureTests: XCTestCase {
    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("simshot-resizer-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    private func makePNG(width: Int, height: Int) -> CGImage {
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
        context.setFillColor(CGColor(srgbRed: 0.2, green: 0.4, blue: 0.6, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    // MARK: - loadCGImage failures

    func testLoadMissingFile() {
        let dir = try! tempDir()
        let url = dir.appendingPathComponent("nope.png")
        XCTAssertThrowsError(try Resizer.loadCGImage(at: url)) { error in
            guard case ResizerError.loadFailed(let failedURL, let reason) = error else {
                return XCTFail("expected .loadFailed, got \(error)")
            }
            XCTAssertEqual(failedURL, url)
            XCTAssertTrue(reason.contains("no such file"), "reason should be actionable: \(reason)")
        }
    }

    func testLoadDirectory() {
        let dir = try! tempDir()
        XCTAssertThrowsError(try Resizer.loadCGImage(at: dir)) { error in
            guard case ResizerError.loadFailed(_, let reason) = error else {
                return XCTFail("expected .loadFailed, got \(error)")
            }
            XCTAssertTrue(reason.contains("directory"), "reason should mention directory: \(reason)")
        }
    }

    func testLoadCorruptFile() throws {
        let dir = try tempDir()
        let url = dir.appendingPathComponent("garbage.png")
        try Data("this is not an image".utf8).write(to: url)
        XCTAssertThrowsError(try Resizer.loadCGImage(at: url)) { error in
            guard case ResizerError.loadFailed(_, let reason) = error else {
                return XCTFail("expected .loadFailed, got \(error)")
            }
            XCTAssertTrue(reason.contains("corrupt") || reason.contains("unsupported"))
        }
    }

    // MARK: - writePNG failures

    func testWriteToDirectoryPath() throws {
        let dir = try tempDir()
        let target = dir.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        XCTAssertThrowsError(try Resizer.writePNG(makePNG(width: 10, height: 10), to: target)) { error in
            guard case ResizerError.writeFailed(_, let reason) = error else {
                return XCTFail("expected .writeFailed, got \(error)")
            }
            XCTAssertTrue(reason.contains("directory"), "reason should mention directory: \(reason)")
        }
    }

    func testWriteToMissingParentDirectory() throws {
        let dir = try tempDir()
        let url = dir.appendingPathComponent("missing").appendingPathComponent("out.png")
        XCTAssertThrowsError(try Resizer.writePNG(makePNG(width: 10, height: 10), to: url)) { error in
            guard case ResizerError.writeFailed(_, let reason) = error else {
                return XCTFail("expected .writeFailed, got \(error)")
            }
            XCTAssertTrue(reason.contains("does not exist"), "reason should be actionable: \(reason)")
        }
    }

    func testRefusesToOverwriteSymlink() throws {
        let dir = try tempDir()
        let victim = dir.appendingPathComponent("victim.png")
        try Resizer.writePNG(makePNG(width: 8, height: 8), to: victim)
        let link = dir.appendingPathComponent("link.png")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: victim.path)

        XCTAssertThrowsError(try Resizer.writePNG(makePNG(width: 16, height: 16), to: link)) { error in
            guard case ResizerError.writeFailed(_, let reason) = error else {
                return XCTFail("expected .writeFailed, got \(error)")
            }
            XCTAssertTrue(reason.contains("symlink"), "reason should mention symlink: \(reason)")
        }
        // The victim must be untouched.
        let victimImage = try Resizer.loadCGImage(at: victim)
        XCTAssertEqual(victimImage.width, 8)
    }

    func testRefusesToWriteThroughSymlinkedDirectory() throws {
        let dir = try tempDir()
        let realParent = dir.appendingPathComponent("real")
        try FileManager.default.createDirectory(at: realParent, withIntermediateDirectories: false)
        let linkParent = dir.appendingPathComponent("linked")
        try FileManager.default.createSymbolicLink(atPath: linkParent.path, withDestinationPath: realParent.path)

        let url = linkParent.appendingPathComponent("out.png")
        XCTAssertThrowsError(try Resizer.writePNG(makePNG(width: 16, height: 16), to: url)) { error in
            guard case ResizerError.writeFailed(_, let reason) = error else {
                return XCTFail("expected .writeFailed, got \(error)")
            }
            XCTAssertTrue(reason.contains("symlink"), "reason should mention symlink: \(reason)")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: realParent.appendingPathComponent("out.png").path))
    }

    // MARK: - makeAppStoreImage

    func testMakeAppStoreImageWithMissingInput() throws {
        let dir = try tempDir()
        let input = dir.appendingPathComponent("missing.png")
        let output = dir.appendingPathComponent("out.png")
        let target = DeviceSpec.matchTarget(width: 660, height: 1434)!
        XCTAssertThrowsError(try Resizer.makeAppStoreImage(input: input, output: output, target: target))
    }
}
