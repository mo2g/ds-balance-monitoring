import XCTest
@testable import DSBalanceMonitor

final class SettingsAndFormattingTests: XCTestCase {
    func testSettingsDefaults() {
        let defaults = UserDefaults(suiteName: "test.settings.defaults")!
        defaults.removePersistentDomain(forName: "test.settings.defaults")
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.threshold, 5.0)
        XCTAssertTrue(store.notificationsEnabled)
        XCTAssertEqual(store.menuBarMode, .iconAndValue)
        XCTAssertEqual(store.preferredCurrency, "CNY")
    }

    func testSettingsRoundTrip() {
        let defaults = UserDefaults(suiteName: "test.settings.roundtrip")!
        defaults.removePersistentDomain(forName: "test.settings.roundtrip")
        let store = SettingsStore(defaults: defaults)
        store.threshold = 8.5
        store.menuBarMode = .iconOnly
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.threshold, 8.5)
        XCTAssertEqual(reloaded.menuBarMode, .iconOnly)
    }

    func testSecretStoreRoundTrip() {
        let store = InMemorySecretStore()
        try? store.set("sk-123", for: "deepseek_api_key")
        XCTAssertEqual(store.get("deepseek_api_key"), "sk-123")
        try? store.delete("deepseek_api_key")
        XCTAssertNil(store.get("deepseek_api_key"))
    }

    func testUserDefaultsSecretStoreRoundTrip() throws {
        let suite = "test.secret.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsSecretStore(defaults: defaults)
        XCTAssertNil(store.get("deepseek_api_key"))
        try store.set("sk-user-entered", for: "deepseek_api_key")
        XCTAssertEqual(store.get("deepseek_api_key"), "sk-user-entered")
        try store.delete("deepseek_api_key")
        XCTAssertNil(store.get("deepseek_api_key"))
    }

    func testStatusTextUsesPreferredCurrency() {
        let balances = [
            BalanceInfo(currency: "CNY", totalBalance: 4.826, grantedBalance: 0, toppedUpBalance: 4.826),
            BalanceInfo(currency: "USD", totalBalance: 1.5, grantedBalance: 0, toppedUpBalance: 1.5),
        ]
        XCTAssertEqual(BalanceFormatting.statusText(balances: balances, preferredCurrency: "CNY"), "¥4.83")
        XCTAssertEqual(BalanceFormatting.statusText(balances: balances, preferredCurrency: "USD"), "$1.50")
        XCTAssertEqual(BalanceFormatting.statusText(balances: [], preferredCurrency: "CNY"), "—")
    }
}
