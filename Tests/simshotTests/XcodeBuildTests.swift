import Foundation
import XCTest

@testable import SimshotCore

final class XcodeBuildTests: XCTestCase {
    private func tempAppDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("simshot-xcodebuild-\(UUID().uuidString)")
            .appendingPathComponent("MyApp.app")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir.deletingLastPathComponent()) }
        return dir
    }

    func testBundleIdentifierReadsXMLPlist() throws {
        let app = try tempAppDir()
        let plist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>CFBundleIdentifier</key>
                <string>com.example.myapp</string>
            </dict>
            </plist>
            """
        try plist.write(to: app.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
        XCTAssertEqual(XcodeBuild.bundleIdentifier(at: app), "com.example.myapp")
    }

    func testBundleIdentifierReadsBinaryPlist() throws {
        let app = try tempAppDir()
        let plist: [String: Any] = ["CFBundleIdentifier": "com.example.binary"]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
        try data.write(to: app.appendingPathComponent("Info.plist"))
        XCTAssertEqual(XcodeBuild.bundleIdentifier(at: app), "com.example.binary")
    }

    func testBundleIdentifierReturnsNilWhenPlistMissing() throws {
        let app = try tempAppDir()
        XCTAssertNil(XcodeBuild.bundleIdentifier(at: app))
    }

    func testBundleIdentifierReturnsNilWhenKeyMissing() throws {
        let app = try tempAppDir()
        let plist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <plist version="1.0"><dict><key>CFBundleName</key><string>MyApp</string></dict></plist>
            """
        try plist.write(to: app.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
        XCTAssertNil(XcodeBuild.bundleIdentifier(at: app))
    }

    func testBundleIdentifierReturnsNilWhenEmpty() throws {
        let app = try tempAppDir()
        let plist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <plist version="1.0"><dict><key>CFBundleIdentifier</key><string>   </string></dict></plist>
            """
        try plist.write(to: app.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
        XCTAssertNil(XcodeBuild.bundleIdentifier(at: app))
    }

    func testBundleIdentifierReturnsNilForMalformedPlist() throws {
        let app = try tempAppDir()
        try Data("not a plist".utf8).write(to: app.appendingPathComponent("Info.plist"))
        XCTAssertNil(XcodeBuild.bundleIdentifier(at: app))
    }

    // MARK: - findApp

    private func makeDerivedData(config: String = "Debug-iphonesimulator", appName: String = "MyApp.app") throws
        -> String
    {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("simshot-dd-\(UUID().uuidString)")
        let products = root.appendingPathComponent("Build/Products")
        let configDir = products.appendingPathComponent(config)
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: configDir.appendingPathComponent(appName), withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root.path
    }

    func testFindAppInDebugIphonesimulator() throws {
        let dd = try makeDerivedData()
        XCTAssertEqual(XcodeBuild.findApp(derivedDataPath: dd)?.lastPathComponent, "MyApp.app")
    }

    func testFindAppInReleaseIphonesimulator() throws {
        let dd = try makeDerivedData(config: "Release-iphonesimulator", appName: "MyApp.app")
        XCTAssertEqual(XcodeBuild.findApp(derivedDataPath: dd)?.lastPathComponent, "MyApp.app")
    }

    func testFindAppPrefersDebugOverRelease() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("simshot-dd-\(UUID().uuidString)")
        let products = root.appendingPathComponent("Build/Products")
        for config in ["Debug-iphonesimulator", "Release-iphonesimulator"] {
            let dir = products.appendingPathComponent(config)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(
                at: dir.appendingPathComponent("App-\(config).app"), withIntermediateDirectories: true)
        }
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        XCTAssertEqual(
            XcodeBuild.findApp(derivedDataPath: root.path)?.lastPathComponent, "App-Debug-iphonesimulator.app")
    }

    func testFindAppTopLevel() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("simshot-dd-\(UUID().uuidString)")
        let products = root.appendingPathComponent("Build/Products")
        try FileManager.default.createDirectory(at: products, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: products.appendingPathComponent("Top.app"), withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        XCTAssertEqual(XcodeBuild.findApp(derivedDataPath: root.path)?.lastPathComponent, "Top.app")
    }

    func testFindAppReturnsNilWhenMissing() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("simshot-dd-\(UUID().uuidString)")
        XCTAssertNil(XcodeBuild.findApp(derivedDataPath: root.path))
    }

    func testFindAppIgnoresNonIphonesimulatorDirs() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("simshot-dd-\(UUID().uuidString)")
        let products = root.appendingPathComponent("Build/Products")
        let other = products.appendingPathComponent("MacOSX")
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: other.appendingPathComponent("MyApp.app"), withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        XCTAssertNil(XcodeBuild.findApp(derivedDataPath: root.path))
    }
}
