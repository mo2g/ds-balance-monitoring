import Foundation
import Combine

public final class AppState: ObservableObject {
    @Published public private(set) var balances: [BalanceInfo] = []
    @Published public private(set) var lastUpdated: Date?
    @Published public private(set) var lastError: String?
    @Published public private(set) var statusText: String = "—"

    private let preferredCurrency: @Sendable () -> String

    public init(preferredCurrency: @escaping @Sendable () -> String) {
        self.preferredCurrency = preferredCurrency
    }

    public func apply(_ response: BalanceResponse) {
        balances = response.balanceInfos
        lastUpdated = Date()
        lastError = nil
        statusText = BalanceFormatting.statusText(balances: balances, preferredCurrency: preferredCurrency())
    }

    public func applyError(_ message: String) {
        lastError = message
        statusText = "⚠️"
    }

    public func refresh() {
        guard lastError == nil else {
            statusText = "⚠️"
            return
        }
        statusText = BalanceFormatting.statusText(balances: balances, preferredCurrency: preferredCurrency())
    }
}
