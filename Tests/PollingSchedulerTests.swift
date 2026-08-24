import XCTest
@testable import DSBalanceMonitor

private final class FakeProvider: BalanceProviding, @unchecked Sendable {
    var results: [Result<BalanceResponse, BalanceAPIError>] = []
    private(set) var callCount = 0
    func fetchBalance() async throws -> BalanceResponse {
        let index = min(callCount, results.count - 1)
        callCount += 1
        return try results[index].get()
    }
}

final class PollingSchedulerTests: XCTestCase {
    func testPollOnceRecordsSnapshotsAndReturnsSuccess() async throws {
        let repo = try BalanceRepository.inMemory()
        let provider = FakeProvider()
        provider.results = [.success(BalanceResponse(isAvailable: true, balanceInfos: [
            BalanceInfo(currency: "CNY", totalBalance: 42, grantedBalance: 0, toppedUpBalance: 42),
        ]))]
        let scheduler = PollingScheduler(provider: provider, repository: repo, interval: 60)
        let response = try await scheduler.pollOnce()
        let snapshots = try repo.rawSnapshots(currency: "CNY", year: Calendar.current.component(.year, from: Date()), range: nil)
        XCTAssertEqual(response.balanceInfos.first?.totalBalance, 42)
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots[0].totalBalance, 42)
        XCTAssertEqual(scheduler.state, .succeeded(snapshots[0].timestamp))
    }

    func testPollFailureIncreasesBackoffAndStateFailed() async throws {
        let repo = try BalanceRepository.inMemory()
        let provider = FakeProvider()
        provider.results = [.failure(.network("boom"))]
        let scheduler = PollingScheduler(provider: provider, repository: repo, interval: 60)
        do {
            _ = try await scheduler.pollOnce()
            XCTFail("expected error")
        } catch {
            XCTAssertEqual(scheduler.state,
                           .failed(Localization.localized(error: .network("boom"),
                                                          language: LanguageManager.shared.resolved)))
        }
        XCTAssertEqual(scheduler.nextDelay(afterConsecutiveFailures: 1), 60)
        XCTAssertEqual(scheduler.nextDelay(afterConsecutiveFailures: 2), 120)
        XCTAssertEqual(scheduler.nextDelay(afterConsecutiveFailures: 3), 240)
        XCTAssertEqual(scheduler.nextDelay(afterConsecutiveFailures: 99), 300)
    }

    func testPollFailureLogsErrorToRepository() async throws {
        let repo = try BalanceRepository.inMemory()
        let provider = FakeProvider()
        provider.results = [.failure(.httpStatus(401))]
        let scheduler = PollingScheduler(provider: provider, repository: repo, interval: 60)
        _ = try? await scheduler.pollOnce()
        let errors = try repo.recentErrors()
        XCTAssertEqual(errors.first,
                           Localization.localized(error: .httpStatus(401), language: LanguageManager.shared.resolved))
    }
}
