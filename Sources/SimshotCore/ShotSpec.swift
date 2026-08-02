import Foundation

/// The screenshot scene launch-argument protocol.
///
/// simshot launches the app under test with a fixed set of arguments that the
/// app (under `#if DEBUG`) interprets to navigate straight to a scene. This is
/// the public contract between simshot and any app that wants screenshot support:
///
/// ```
/// --ui-testing
/// --screenshot-scene <scene>
/// --screenshot-strokes <N>
/// --screenshot-scroll-bottom
/// ```
///
/// `-AppleLanguages (lang)` and `-AppleLocale locale` are also passed so the
/// app renders in the target language.
public enum ScreenshotProtocol {
    public static let uiTestingArgument = "--ui-testing"
    public static let sceneArgument = "--screenshot-scene"
    public static let strokesArgument = "--screenshot-strokes"
    public static let scrollBottomArgument = "--screenshot-scroll-bottom"

    public static let languagesArgument = "-AppleLanguages"
    public static let localeArgument = "-AppleLocale"

    /// Build the argument list passed to `simctl launch`.
    public static func launchArguments(language: String, locale: String, shot: Shot) -> [String] {
        var args: [String] = [
            languagesArgument, "(\(language))",
            localeArgument, locale,
        ]
        if shot.uiTesting {
            args.append(uiTestingArgument)
        }
        args.append(contentsOf: [sceneArgument, shot.scene])
        if let strokes = shot.strokes {
            args.append(contentsOf: [strokesArgument, String(strokes)])
        }
        if shot.scrollBottom {
            args.append(scrollBottomArgument)
        }
        return args
    }
}

/// One screenshot to capture: which scene, plus per-shot capture options.
public struct Shot: Codable, Equatable {
    public let name: String
    public let scene: String
    public let strokes: Int?
    public let scrollBottom: Bool
    public let wait: Int
    public let uiTesting: Bool

    public init(
        name: String,
        scene: String,
        strokes: Int? = nil,
        scrollBottom: Bool = false,
        wait: Int = 6,
        uiTesting: Bool = true
    ) {
        self.name = name
        self.scene = scene
        self.strokes = strokes
        self.scrollBottom = scrollBottom
        self.wait = wait
        self.uiTesting = uiTesting
    }

    private enum CodingKeys: String, CodingKey {
        case name, scene, strokes, scrollBottom, wait, uiTesting
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        scene = try container.decode(String.self, forKey: .scene)
        strokes = try container.decodeIfPresent(Int.self, forKey: .strokes)
        scrollBottom = try container.decodeIfPresent(Bool.self, forKey: .scrollBottom) ?? false
        wait = try container.decodeIfPresent(Int.self, forKey: .wait) ?? 6
        uiTesting = try container.decodeIfPresent(Bool.self, forKey: .uiTesting) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(scene, forKey: .scene)
        try container.encodeIfPresent(strokes, forKey: .strokes)
        try container.encode(scrollBottom, forKey: .scrollBottom)
        try container.encode(wait, forKey: .wait)
        try container.encode(uiTesting, forKey: .uiTesting)
    }
}

/// JSON config file format: `{ "shots": [ ... ] }`.
public struct ShotsFile: Codable, Equatable {
    public let shots: [Shot]

    public init(shots: [Shot]) {
        self.shots = shots
    }
}

/// Language code → locale mapping for `-AppleLocale`.
public enum LocaleMap {
    /// Map a language code to a locale. Unknown codes are passed through as-is.
    public static func locale(for language: String) -> String {
        let known: [String: String] = [
            "ja": "ja_JP",
            "en": "en_US",
            "ko": "ko_KR",
            "zh-Hans": "zh_CN",
            "zh-Hant": "zh_TW",
            "de": "de_DE",
            "fr": "fr_FR",
            "es": "es_ES",
            "it": "it_IT",
            "pt": "pt_PT",
            "pt-BR": "pt_BR",
            "ru": "ru_RU",
            "ar": "ar_SA",
            "th": "th_TH",
            "vi": "vi_VN",
            "id": "id_ID",
            "nl": "nl_NL",
            "sv": "sv_SE",
            "da": "da_DK",
            "fi": "fi_FI",
            "no": "nb_NO",
            "pl": "pl_PL",
            "tr": "tr_TR",
            "cs": "cs_CZ",
            "hu": "hu_HU",
            "uk": "uk_UA",
        ]
        return known[language] ?? language
    }
}
