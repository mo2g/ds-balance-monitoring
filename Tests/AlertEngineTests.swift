import XCTest
@testable import DSBalanceMonitor

private final class RecordingNotifier: AlertNotifying {
    private(set) var decisions: [AlertDecision] = []
    func notify(_ decision: AlertDecision) {
        decisions.append(decision)
    }
}

private final class ArmedStore {
    var armed: Set<String>
    init(armed: Set<String>) { self.armed = armed }
    func set(_ value: Bool, for currency: String) {
        if value { armed.insert(currency) } else { armed.remove(currency) }
    }
}

final class AlertEngineTests: XCTestCase {
    private func makeEngine(threshold: Double = 5, armed: Set<String> = ["CNY"]) -> (AlertEngine, RecordingNotifier, ArmedStore) {
        let notifier = RecordingNotifier()
        let store = ArmedStore(armed: armed)
        let engine = AlertEngine(thresholdProvider: { threshold },
                                 notifier: notifier,
                                 loadArmed: { store.armed.contains($0) },
                                 persistArmed: { store.set($1, for: $0) })
        return (engine, notifier, store)
    }

    func testFiresOnceWhenDropsBelowThreshold() {
        let (engine, notifier, _) = makeEngine()
        let below = [BalanceInfo(currency: "CNY", totalBalance: 4.9, grantedBalance: 0, toppedUpBalance: 4.9)]
        let first = engine.evaluate(balances: below)
        let second = engine.evaluate(balances: below)
        XCTAssertEqual(first, [AlertDecision(currency: "CNY", totalBalance: 4.9, threshold: 5)])
        XCTAssertTrue(second.isEmpty)
        XCTAssertEqual(notifier.decisions.count, 1)
    }

    func testRearmsAfterBalanceReturnsAboveThreshold() {
        let (engine, notifier, _) = makeEngine()
        _ = engine.evaluate(balances: [BalanceInfo(currency: "CNY", totalBalance: 4.9, grantedBalance: 0, toppedUpBalance: 4.9)])
        _ = engine.evaluate(balances: [BalanceInfo(currency: "CNY", totalBalance: 20, grantedBalance: 0, toppedUpBalance: 20)])
        let decisions = engine.evaluate(balances: [BalanceInfo(currency: "CNY", totalBalance: 4.8, grantedBalance: 0, toppedUpBalance: 4.8)])
        XCTAssertEqual(decisions.count, 1)
        XCTAssertEqual(notifier.decisions.count, 2)
    }

    func testNoAlertAboveThreshold() {
        let (engine, notifier, _) = makeEngine()
        let decisions = engine.evaluate(balances: [BalanceInfo(currency: "CNY", totalBalance: 100, grantedBalance: 0, toppedUpBalance: 100)])
        XCTAssertTrue(decisions.isEmpty)
        XCTAssertTrue(notifier.decisions.isEmpty)
    }

    func testPerCurrencyIndependentState() {
        let (engine, notifier, store) = makeEngine(armed: ["CNY", "USD"])
        _ = engine.evaluate(balances: [
            BalanceInfo(currency: "CNY", totalBalance: 1, grantedBalance: 0, toppedUpBalance: 1),
            BalanceInfo(currency: "USD", totalBalance: 10, grantedBalance: 0, toppedUpBalance: 10),
        ])
        XCTAssertEqual(notifier.decisions.map(\.currency), ["CNY"])
        XCTAssertFalse(store.armed.contains("CNY"))
        XCTAssertTrue(store.armed.contains("USD"))
    }
}
