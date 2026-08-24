import XCTest
@testable import DSBalanceMonitor

final class AppStateTests: XCTestCase {
    func testApplyResponseSetsBalancesAndStatus() {
        let state = AppState(preferredCurrency: { "CNY" })
        state.apply(BalanceResponse(isAvailable: true, balanceInfos: [
            BalanceInfo(currency: "CNY", totalBalance: 6.789, grantedBalance: 0, toppedUpBalance: 6.789),
        ]))
        XCTAssertEqual(state.balances.count, 1)
        XCTAssertEqual(state.statusText, "¥6.79")
        XCTAssertNil(state.lastError)
    }

    func testApplyErrorClearsStaleDataAndSetsMessage() {
        let state = AppState(preferredCurrency: { "CNY" })
        state.applyError("网络错误：boom")
        XCTAssertEqual(state.lastError, "网络错误：boom")
        XCTAssertEqual(state.statusText, "⚠️")
    }
}

extension AppStateTests {
    func testRefreshKeepsWarningWhenErrorActive() {
        let state = AppState(preferredCurrency: { "CNY" })
        state.applyError("网络错误：boom")
        state.refresh()
        XCTAssertEqual(state.statusText, "⚠️")
    }

    func testRefreshRecomputesStatusAfterApply() {
        let state = AppState(preferredCurrency: { "CNY" })
        state.apply(BalanceResponse(isAvailable: true, balanceInfos: [
            BalanceInfo(currency: "CNY", totalBalance: 6.789, grantedBalance: 0, toppedUpBalance: 6.789),
        ]))
        state.refresh()
        XCTAssertEqual(state.statusText, "¥6.79")
    }
}
