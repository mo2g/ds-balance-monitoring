import XCTest
import Combine
@testable import DSBalanceMonitor

final class LocalizationTests: XCTestCase {
    func testChineseAndEnglishLookup() {
        XCTAssertEqual(Localization.string("granularity.minute", language: .zhHans), "分")
        XCTAssertEqual(Localization.string("granularity.minute", language: .en), "Minute")
        XCTAssertEqual(Localization.string("common.settings", language: .zhHans), "设置")
        XCTAssertEqual(Localization.string("common.settings", language: .en), "Settings")
    }

    func testMissingKeyFallsBackToKey() {
        XCTAssertEqual(Localization.string("does.not.exist", language: .en), "does.not.exist")
    }

    func testErrorLocalizationBothLanguages() {
        XCTAssertEqual(Localization.localized(error: .httpStatus(401), language: .zhHans), "API Key 无效（401）")
        XCTAssertEqual(Localization.localized(error: .httpStatus(401), language: .en), "Invalid API key (401)")
        XCTAssertEqual(Localization.localized(error: .network("boom"), language: .zhHans), "网络错误：boom")
        XCTAssertEqual(Localization.localized(error: .network("boom"), language: .en), "Network error: boom")
        XCTAssertEqual(Localization.localized(error: .missingAPIKey, language: .en), "API key is not configured")
    }

    func testPreferencePersistsAcrossInstances() {
        let suiteName = "test.localization.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = LanguageManager(defaults: defaults)
        XCTAssertEqual(first.preference, .system)
        first.preference = .en
        XCTAssertEqual(first.resolved, .en)

        let second = LanguageManager(defaults: defaults)
        XCTAssertEqual(second.preference, .en)
    }

    func testSystemLanguageResolution() {
        let zh = LanguageManager(defaults: UserDefaults(suiteName: "test.loc.zh")!,
                                 systemLanguages: { ["zh-Hans-CN"] })
        XCTAssertEqual(zh.resolved, .zhHans)

        let en = LanguageManager(defaults: UserDefaults(suiteName: "test.loc.en")!,
                                 systemLanguages: { ["en-US"] })
        XCTAssertEqual(en.resolved, .en)

        let unknown = LanguageManager(defaults: UserDefaults(suiteName: "test.loc.fr")!,
                                      systemLanguages: { ["fr-FR"] })
        XCTAssertEqual(unknown.resolved, .en)
    }

    func testManagerLookupFollowsPreference() {
        let suiteName = "test.loc.lookup.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = LanguageManager(defaults: defaults, systemLanguages: { ["en-US"] })
        XCTAssertEqual(manager.t("granularity.month"), "Month")
        manager.preference = .zhHans
        XCTAssertEqual(manager.t("granularity.month"), "月")
    }

    func testMenuBarModeTitles() {
        XCTAssertEqual(MenuBarDisplayMode.iconAndValue.title(language: .zhHans), "图标 + 数字")
        XCTAssertEqual(MenuBarDisplayMode.iconAndValue.title(language: .en), "Icon + Value")
        XCTAssertEqual(MenuBarDisplayMode.iconOnly.title(language: .en), "Icon Only")
        XCTAssertEqual(MenuBarDisplayMode.valueOnly.title(language: .en), "Value Only")
    }
}
