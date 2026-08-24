import Foundation

public enum PollingState: Equatable {
    case idle
    case polling
    case succeeded(Date)
    case failed(String)
}

public final class PollingScheduler {
    public private(set) var state: PollingState = .idle
    public let interval: TimeInterval
    private let provider: any BalanceProviding
    private let repository: BalanceRepository
    private let onAlert: @Sendable ([BalanceInfo]) -> Void
    private var consecutiveFailures = 0
    private let backoffSteps: [TimeInterval]

    public init(provider: any BalanceProviding,
                repository: BalanceRepository,
                interval: TimeInterval = 60,
                backoffSteps: [TimeInterval] = [60, 120, 240, 300],
                onAlert: @escaping @Sendable ([BalanceInfo]) -> Void = { _ in }) {
        self.provider = provider
        self.repository = repository
        self.interval = interval
        self.backoffSteps = backoffSteps
        self.onAlert = onAlert
    }

    public func nextDelay(afterConsecutiveFailures failures: Int) -> TimeInterval {
        let index = min(max(failures - 1, 0), backoffSteps.count - 1)
        return backoffSteps[index]
    }

    @discardableResult
    public func pollOnce() async throws -> BalanceResponse {
        state = .polling
        do {
            let response = try await provider.fetchBalance()
            let now = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))
            try repository.record(balances: response.balanceInfos, at: now)
            consecutiveFailures = 0
            state = .succeeded(now)
            onAlert(response.balanceInfos)
            return response
        } catch {
            consecutiveFailures += 1
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            try? repository.logError(message)
            state = .failed(message)
            throw error
        }
    }
}
