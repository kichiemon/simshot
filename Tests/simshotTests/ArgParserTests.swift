import XCTest

@testable import SimshotCore

final class ArgParserTests: XCTestCase {
    // MARK: - Happy path

    func testParsesAllOptions() throws {
        let options = try ArgParser.parseShoot([
            "--project", "MyApp.xcodeproj",
            "--scheme", "MyApp",
            "--bundle-id", "com.example.myapp",
            "--devices", "iphone-17-pro-max,ipad-pro-13",
            "--langs", "ja,en",
            "--locales", "ja=ja_JP,en=en_US",
            "--scenes", "home,detail",
            "--wait", "8",
            "--timeout", "600",
            "--output", "shots",
            "--derived-data", "/tmp/derived",
            "--status-bar-time", "10:09",
            "--status-bar-battery", "80",
            "--resize",
            "--no-ui-testing",
            "--no-clean",
            "--keep-running",
            "--verbose",
        ])

        XCTAssertEqual(options.project, "MyApp.xcodeproj")
        XCTAssertNil(options.workspace)
        XCTAssertEqual(options.scheme, "MyApp")
        XCTAssertEqual(options.bundleID, "com.example.myapp")
        XCTAssertEqual(options.devices, ["iphone-17-pro-max", "ipad-pro-13"])
        XCTAssertEqual(options.languages, ["ja", "en"])
        XCTAssertEqual(options.localeOverrides, ["ja": "ja_JP", "en": "en_US"])
        XCTAssertEqual(options.scenes, ["home", "detail"])
        XCTAssertEqual(options.wait, 8)
        XCTAssertEqual(options.timeout, 600)
        XCTAssertEqual(options.outputDir, "shots")
        XCTAssertEqual(options.derivedData, "/tmp/derived")
        XCTAssertEqual(options.statusBarTime, "10:09")
        XCTAssertEqual(options.statusBarBattery, 80)
        XCTAssertTrue(options.resize)
        XCTAssertFalse(options.uiTesting)
        XCTAssertFalse(options.cleanInstall)
        XCTAssertFalse(options.shutdownAfter)
        XCTAssertTrue(options.verbose)
        XCTAssertEqual(options.shots.count, 2)
        XCTAssertEqual(options.shots[0].name, "home.png")
        XCTAssertEqual(options.shots[1].scene, "detail")
    }

    func testInlineEqualsSyntax() throws {
        let options = try ArgParser.parseShoot([
            "--project=MyApp.xcodeproj",
            "--scheme=MyApp",
            "--bundle-id=com.example.myapp",
            "--devices=iphone-17-pro-max",
            "--scenes=home",
        ])
        XCTAssertEqual(options.project, "MyApp.xcodeproj")
        XCTAssertEqual(options.bundleID, "com.example.myapp")
        XCTAssertEqual(options.devices, ["iphone-17-pro-max"])
    }

    func testWorkspaceAlternative() throws {
        let options = try ArgParser.parseShoot([
            "--workspace", "MyApp.xcworkspace",
            "--scheme", "MyApp",
            "--bundle-id", "com.example.myapp",
            "--devices", "ipad-pro-13",
            "--scenes", "home",
        ])
        XCTAssertEqual(options.workspace, "MyApp.xcworkspace")
        XCTAssertNil(options.project)
    }

    func testAppPathSkipsBuildRequirements() throws {
        let options = try ArgParser.parseShoot([
            "--app-path", "/tmp/Build/Products/Debug-iphonesimulator/MyApp.app",
            "--bundle-id", "com.example.myapp",
            "--devices", "iphone-17-pro-max",
            "--scenes", "home",
        ])
        XCTAssertEqual(options.appPath?.path, "/tmp/Build/Products/Debug-iphonesimulator/MyApp.app")
        XCTAssertNil(options.scheme)
    }

    func testDefaultsFilled() throws {
        let options = try ArgParser.parseShoot([
            "--project", "MyApp.xcodeproj",
            "--scheme", "MyApp",
            "--bundle-id", "com.example.myapp",
            "--devices", "iphone-17-pro-max",
            "--scenes", "home,detail",
        ])
        XCTAssertEqual(options.languages, ["en"], "language defaults to en")
        XCTAssertEqual(options.shots.count, 2)
        XCTAssertEqual(options.shots[0].wait, 6)
        XCTAssertTrue(options.shots[0].uiTesting)
        XCTAssertEqual(options.outputDir, "appstore")
        XCTAssertEqual(options.timeout, 300)
        XCTAssertFalse(options.resize)
    }

    func testShotsFileTakesPrecedenceOverScenes() throws {
        let config = try writeTempShots(
            """
            { "shots": [
                { "name": "01_trace.png", "scene": "trace", "strokes": 2, "wait": 9, "uiTesting": false }
            ] }
            """)
        let options = try ArgParser.parseShoot([
            "--project", "MyApp.xcodeproj",
            "--scheme", "MyApp",
            "--bundle-id", "com.example.myapp",
            "--devices", "iphone-17-pro-max",
            "--scenes", "home",
            "--shots", config.path,
        ])
        XCTAssertEqual(options.shots.count, 1)
        XCTAssertEqual(options.shots[0].name, "01_trace.png")
        XCTAssertEqual(options.shots[0].strokes, 2)
        XCTAssertEqual(options.shots[0].wait, 9)
        XCTAssertFalse(options.shots[0].uiTesting)
    }

    func testCSVTrimsAndSkipsEmpty() {
        XCTAssertEqual(
            ArgParser.csv(" iphone-17-pro-max , ,ipad-pro-13 "),
            ["iphone-17-pro-max", "ipad-pro-13"]
        )
        XCTAssertEqual(ArgParser.csv(""), [])
    }

    // MARK: - Error cases

    func testUnknownOption() {
        assertUsage(
            [
                "--project", "MyApp.xcodeproj", "--scheme", "MyApp", "--bundle-id", "c", "--devices", "d",
                "--scenes", "home", "--bogus",
            ], contains: "--bogus")
    }

    func testMissingValueForFlag() {
        assertUsage(["--project", "MyApp.xcodeproj", "--scheme"], contains: "--scheme")
    }

    func testUnexpectedPositionalArgument() {
        assertUsage(["MyApp.xcodeproj"], contains: "positional")
    }

    func testMissingProjectWorkspaceAndAppPath() {
        assertUsage(
            ["--scheme", "MyApp", "--bundle-id", "c", "--devices", "d", "--scenes", "home"],
            contains: "--project")
    }

    func testMissingScheme() {
        assertUsage(
            ["--project", "MyApp.xcodeproj", "--bundle-id", "c", "--devices", "d", "--scenes", "home"],
            contains: "--scheme")
    }

    func testMissingBundleID() {
        assertUsage(
            ["--project", "MyApp.xcodeproj", "--scheme", "MyApp", "--devices", "d", "--scenes", "home"],
            contains: "--bundle-id")
    }

    func testMissingDevices() {
        assertUsage(
            ["--project", "MyApp.xcodeproj", "--scheme", "MyApp", "--bundle-id", "c", "--scenes", "home"],
            contains: "--devices")
    }

    func testMissingScenesAndShots() {
        assertUsage(
            ["--project", "MyApp.xcodeproj", "--scheme", "MyApp", "--bundle-id", "c", "--devices", "d"],
            contains: "--shots")
    }

    func testInvalidTimeout() {
        assertUsage(
            [
                "--project", "MyApp.xcodeproj", "--scheme", "MyApp", "--bundle-id", "c", "--devices", "d",
                "--scenes", "home", "--timeout", "abc",
            ],
            contains: "--timeout")
    }

    func testInvalidWait() {
        assertUsage(
            [
                "--project", "MyApp.xcodeproj", "--scheme", "MyApp", "--bundle-id", "c", "--devices", "d",
                "--scenes", "home", "--wait", "fast",
            ],
            contains: "--wait")
    }

    func testInvalidLocalesEntry() {
        assertUsage(
            [
                "--project", "MyApp.xcodeproj", "--scheme", "MyApp", "--bundle-id", "c", "--devices", "d",
                "--scenes", "home", "--locales", "ja",
            ],
            contains: "--locales")
    }

    func testMissingShotsFile() {
        XCTAssertThrowsError(
            try ArgParser.parseShoot([
                "--project", "MyApp.xcodeproj",
                "--scheme", "MyApp",
                "--bundle-id", "com.example.myapp",
                "--devices", "iphone-17-pro-max",
                "--shots", "/nonexistent/shots.json",
            ])
        ) { error in
            guard case SimshotError.notFound(let message) = error else {
                return XCTFail("expected .notFound, got \(error)")
            }
            XCTAssertTrue(message.contains("shots"))
        }
    }

    func testMalformedShotsJSON() throws {
        let config = try writeTempShots("not json at all")
        XCTAssertThrowsError(
            try ArgParser.parseShoot([
                "--project", "MyApp.xcodeproj",
                "--scheme", "MyApp",
                "--bundle-id", "com.example.myapp",
                "--devices", "iphone-17-pro-max",
                "--shots", config.path,
            ])
        ) { error in
            guard case SimshotError.invalid(let message) = error else {
                return XCTFail("expected .invalid, got \(error)")
            }
            XCTAssertTrue(message.contains("shots config"))
        }
    }

    private func assertUsage(
        _ args: [String],
        contains needle: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try ArgParser.parseShoot(args), file: file, line: line) { error in
            guard case SimshotError.usage(let message) = error else {
                return XCTFail("expected .usage, got \(error)", file: file, line: line)
            }
            XCTAssertTrue(
                message.contains(needle), "message should mention '\(needle)': \(message)", file: file,
                line: line)
        }
    }

    private func writeTempShots(_ content: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("simshot-args-\(UUID().uuidString).json")
        try content.write(to: url, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
