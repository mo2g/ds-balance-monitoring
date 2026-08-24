import Foundation

public struct AlertDecision: Equatable {
    public var currency: String
    public var totalBalance: Double
    public var threshold: Double

    public init(currency: String, totalBalance: Double, threshold: Double) {
        self.currency = currency
        self.totalBalance = totalBalance
        self.threshold = threshold
    }
}

public protocol AlertNotifying {
    func notify(_ decision: AlertDecision)
}

public final class AlertEngine {
    private let thresholdProvider: @Sendable () -> Double
    private let notifier: any AlertNotifying
    private let loadArmed: @Sendable (String) -> Bool
    private let persistArmed: @Sendable (String, Bool) -> Void
    private var armed: [String: Bool] = [:]

    public init(thresholdProvider: @escaping @Sendable () -> Double,
                notifier: any AlertNotifying,
                loadArmed: @escaping @Sendable (String) -> Bool,
                persistArmed: @escaping @Sendable (String, Bool) -> Void) {
        self.thresholdProvider = thresholdProvider
        self.notifier = notifier
        self.loadArmed = loadArmed
        self.persistArmed = persistArmed
    }

    @discardableResult
    public func evaluate(balances: [BalanceInfo]) -> [AlertDecision] {
        let threshold = thresholdProvider()
        var fired: [AlertDecision] = []
        for info in balances {
            let currency = info.currency
            let isArmed = armed[currency] ?? loadArmed(currency)
            if info.totalBalance >= threshold {
                if !isArmed {
                    armed[currency] = true
                    persistArmed(currency, true)
                }
            } else if isArmed {
                let decision = AlertDecision(currency: currency, totalBalance: info.totalBalance, threshold: threshold)
                fired.append(decision)
                notifier.notify(decision)
                armed[currency] = false
                persistArmed(currency, false)
            }
        }
        return fired
    }
}
