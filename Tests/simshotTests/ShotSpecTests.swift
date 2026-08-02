import XCTest

@testable import SimshotCore

final class ShotSpecTests: XCTestCase {
    func testLocaleMap() {
        XCTAssertEqual(LocaleMap.locale(for: "ja"), "ja_JP")
        XCTAssertEqual(LocaleMap.locale(for: "en"), "en_US")
        XCTAssertEqual(LocaleMap.locale(for: "zh-Hans"), "zh_CN")
        XCTAssertEqual(LocaleMap.locale(for: "xx"), "xx")
    }

    func testLaunchArguments() {
        let shot = Shot(name: "02_transform.png", scene: "trace", strokes: 2, wait: 7)
        let args = ScreenshotProtocol.launchArguments(language: "ja", locale: "ja_JP", shot: shot)
        XCTAssertEqual(
            args,
            [
                "-AppleLanguages", "(ja)",
                "-AppleLocale", "ja_JP",
                "--ui-testing",
                "--screenshot-scene", "trace",
                "--screenshot-strokes", "2",
            ])
    }

    func testLaunchArgumentsScrollBottomAndNoUITesting() {
        let shot = Shot(name: "07_store_tip.png", scene: "store", scrollBottom: true, uiTesting: false)
        let args = ScreenshotProtocol.launchArguments(language: "en", locale: "en_US", shot: shot)
        XCTAssertEqual(
            args,
            [
                "-AppleLanguages", "(en)",
                "-AppleLocale", "en_US",
                "--screenshot-scene", "store",
                "--screenshot-scroll-bottom",
            ])
    }

    func testShotDecodingWithDefaults() throws {
        let json = """
            { "name": "04_home.png", "scene": "home" }
            """
        let data = json.data(using: .utf8)!
        let shot = try JSONDecoder().decode(Shot.self, from: data)
        XCTAssertEqual(shot.name, "04_home.png")
        XCTAssertEqual(shot.scene, "home")
        XCTAssertNil(shot.strokes)
        XCTAssertFalse(shot.scrollBottom)
        XCTAssertEqual(shot.wait, 6)
        XCTAssertTrue(shot.uiTesting)
    }

    func testShotsFileDecoding() throws {
        let json = """
            { "shots": [
                { "name": "01_trace.png", "scene": "trace", "strokes": 1, "wait": 6 },
                { "name": "06_store.png", "scene": "store", "scrollBottom": true, "wait": 8 }
            ] }
            """
        let data = json.data(using: .utf8)!
        let file = try JSONDecoder().decode(ShotsFile.self, from: data)
        XCTAssertEqual(file.shots.count, 2)
        XCTAssertEqual(file.shots[0].strokes, 1)
        XCTAssertTrue(file.shots[1].scrollBottom)
    }
}
