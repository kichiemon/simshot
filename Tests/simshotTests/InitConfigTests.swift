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

final class InitConfigInvalidAnswersTests: XCTestCase {
    func testTemplateWithEmptyDevicesDoesNotCrash() {
        var answers = InitConfig.Answers.defaults
        answers.devices = []
        let template = InitConfig.template(answers: answers)
        XCTAssertTrue(template.contains("devices:"), "devices key must still be present")
        XCTAssertFalse(template.contains("  - iphone-17-pro-max"), "no device bullets expected")
        XCTAssertFalse(template.contains("  - ipad-pro-13"), "no device bullets expected")
    }

    func testTemplateWithEmptyScenesDoesNotCrash() {
        var answers = InitConfig.Answers.defaults
        answers.scenes = []
        let template = InitConfig.template(answers: answers)
        XCTAssertTrue(template.contains("scenes:"))
        XCTAssertFalse(template.contains("  - home"))
    }

    func testTemplateWithEmptyLanguagesDoesNotCrash() {
        var answers = InitConfig.Answers.defaults
        answers.languages = []
        let template = InitConfig.template(answers: answers)
        XCTAssertTrue(template.contains("langs:"))
    }

    func testTemplateWithEmptyListsIsWellFormed() {
        var answers = InitConfig.Answers.defaults
        answers.devices = []
        answers.languages = []
        answers.scenes = []
        let template = InitConfig.template(answers: answers)
        XCTAssertTrue(template.contains("devices:"))
        XCTAssertTrue(template.contains("langs:"))
        XCTAssertTrue(template.contains("scenes:"))
        XCTAssertFalse(template.contains("  - "))
        XCTAssertFalse(template.contains("--devices --langs"))
        XCTAssertTrue(template.hasSuffix("\n"))
    }

    func testTemplateWithNilProjectAndSchemeUsesPlaceholders() {
        var answers = InitConfig.Answers.defaults
        answers.project = nil
        answers.scheme = nil
        let template = InitConfig.template(answers: answers)
        XCTAssertTrue(template.contains("--project <project>"))
        XCTAssertTrue(template.contains("--scheme <scheme>"))
        XCTAssertTrue(template.contains("# project: MyApp.xcodeproj"))
        XCTAssertTrue(template.contains("# scheme: MyApp"))
        XCTAssertFalse(template.contains("\nproject: MyApp.xcodeproj"))
        XCTAssertFalse(template.contains("\nscheme: MyApp"))
    }

    func testTemplateWithEmptyBundleIDStillGeneratesHeader() {
        var answers = InitConfig.Answers.defaults
        answers.bundleID = ""
        let template = InitConfig.template(answers: answers)
        XCTAssertTrue(template.contains("# simshot configuration"))
        XCTAssertTrue(template.contains("bundle-id: "))
    }

    func testTemplateMentionsShotsOverrideForFullControl() {
        let template = InitConfig.template(answers: .defaults)
        XCTAssertTrue(template.contains("--shots"))
        XCTAssertTrue(template.contains("examples/shots.json"))
    }

    func testAnswersEquatable() {
        let a = InitConfig.Answers.defaults
        var b = InitConfig.Answers.defaults
        XCTAssertEqual(a, b)
        b.scenes = ["home"]
        XCTAssertNotEqual(a, b)
    }
}
