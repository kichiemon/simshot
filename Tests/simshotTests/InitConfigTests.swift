import XCTest

@testable import SimshotCore

final class InitConfigTests: XCTestCase {
    func testDefaults() {
        let answers = InitConfig.Answers.defaults
        XCTAssertEqual(answers.bundleID, "com.example.myapp")
        XCTAssertEqual(answers.project, "MyApp.xcodeproj")
        XCTAssertEqual(answers.scheme, "MyApp")
        XCTAssertEqual(answers.devices, ["iphone-17-pro-max", "ipad-pro-13"])
        XCTAssertEqual(answers.languages, ["ja", "en"])
        XCTAssertEqual(answers.scenes, ["home", "detail", "settings"])
        XCTAssertEqual(answers.output, "appstore")
        XCTAssertTrue(answers.resize)
    }

    func testTemplateContainsAnswers() {
        let template = InitConfig.template(answers: .defaults)
        XCTAssertTrue(template.contains("com.example.myapp"))
        XCTAssertTrue(template.contains("MyApp.xcodeproj"))
        XCTAssertTrue(template.contains("MyApp"))
        XCTAssertTrue(template.contains("iphone-17-pro-max"))
        XCTAssertTrue(template.contains("ipad-pro-13"))
        XCTAssertTrue(template.contains("home"))
        XCTAssertTrue(template.contains("settings"))
        XCTAssertTrue(template.contains("appstore"))
        XCTAssertTrue(template.contains("resize: true"))
    }

    func testTemplateOmitsProjectAndSchemeWhenNil() {
        var answers = InitConfig.Answers.defaults
        answers.project = nil
        answers.scheme = nil
        let template = InitConfig.template(answers: answers)
        XCTAssertTrue(template.contains("# project: MyApp.xcodeproj"))
        XCTAssertTrue(template.contains("# scheme: MyApp"))
        XCTAssertFalse(template.contains("\nproject: MyApp.xcodeproj"), "active project line must be absent")
        XCTAssertFalse(template.contains("\nscheme: MyApp"), "active scheme line must be absent")
    }

    func testTemplateSingleDeviceAndNoResize() {
        var answers = InitConfig.Answers.defaults
        answers.devices = ["iphone-17-pro-max"]
        answers.resize = false
        let template = InitConfig.template(answers: answers)
        XCTAssertTrue(template.contains("  - iphone-17-pro-max"))
        XCTAssertFalse(template.contains("ipad-pro-13"))
        XCTAssertTrue(template.contains("resize: false"))
    }
}
