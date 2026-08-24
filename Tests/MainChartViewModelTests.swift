import XCTest
import Combine
@testable import DSBalanceMonitor

final class MainChartViewModelTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return cal
    }

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0, _ s: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
    }

    private func makeRepo() throws -> BalanceRepository {
        let repo = try BalanceRepository.inMemory()
        repo.calendar = calendar
        return repo
    }

    /// Records minute-spaced samples from `start` for `count` minutes, each
    /// consuming 1.0 from an initial 1000.
    @discardableResult
    private func seedMinuteData(_ repo: BalanceRepository, start: Date, count: Int) throws -> Date {
        var balance = 1000.0
        var latest = start
        for index in 0..<count {
            let t = start.addingTimeInterval(60 * TimeInterval(index))
            balance -= 1
            try repo.record(balances: [BalanceInfo(currency: "CNY", totalBalance: balance,
                                                   grantedBalance: 0, toppedUpBalance: balance)], at: t)
            latest = t
        }
        return latest
    }

    private func makeModel(_ repo: BalanceRepository,
                           granularity: AggregateGranularity,
                           now: Date,
                           updates: PassthroughSubject<Date, Never> = PassthroughSubject()) -> MainChartViewModel {
        let model = MainChartViewModel(repository: repo,
                                       updates: updates.eraseToAnyPublisher(),
                                       now: { now })
        model.granularity = granularity
        model.reload()
        return model
    }

    // MARK: - Minute paging

    func testInitialLoadShowsOnlyNewestMinutePage() throws {
        let repo = try makeRepo()
        // 06:00 .. 19:07, minute-spaced (788 samples).
        try seedMinuteData(repo, start: date(2026, 8, 24, 6, 0), count: 788)
        let model = makeModel(repo, granularity: .minute, now: date(2026, 8, 24, 19, 7))

        XCTAssertEqual(model.points.count, 360) // 13:08 .. 19:07
        XCTAssertEqual(model.points.first!.start, date(2026, 8, 24, 13, 8))
        XCTAssertEqual(model.points.last!.start, date(2026, 8, 24, 19, 7))
        XCTAssertEqual(model.loadedRange, DateInterval(start: date(2026, 8, 24, 13, 8),
                                                       end: date(2026, 8, 24, 19, 8)))
        XCTAssertTrue(model.hasMoreEarlier)
        XCTAssertEqual(model.scrollAnchor, date(2026, 8, 24, 17, 7))
        XCTAssertTrue(model.isViewingLatest)
        XCTAssertFalse(model.canReturnToLatest)
    }

    func testLoadOlderPrependsWithoutMovingAnchor() throws {
        let repo = try makeRepo()
        try seedMinuteData(repo, start: date(2026, 8, 24, 6, 0), count: 788)
        let model = makeModel(repo, granularity: .minute, now: date(2026, 8, 24, 19, 7))
        let anchor = model.scrollAnchor

        model.loadOlder()

        XCTAssertEqual(model.points.count, 720)
        XCTAssertEqual(model.points.first!.start, date(2026, 8, 24, 7, 8))
        XCTAssertEqual(model.loadedRange, DateInterval(start: date(2026, 8, 24, 7, 8),
                                                       end: date(2026, 8, 24, 19, 8)))
        XCTAssertEqual(model.scrollAnchor, anchor)
        XCTAssertTrue(model.hasMoreEarlier)
    }

    func testLoadOlderEventuallyExhaustsEarlierData() throws {
        let repo = try makeRepo()
        try seedMinuteData(repo, start: date(2026, 8, 24, 6, 0), count: 788)
        let model = makeModel(repo, granularity: .minute, now: date(2026, 8, 24, 19, 7))
        // Two pages cover 06:00 (first page is 13:08..19:08).
        model.loadOlder() // 07:08
        model.loadOlder() // 01:08
        XCTAssertFalse(model.hasMoreEarlier)
        XCTAssertEqual(model.points.count, 788)
    }

    func testScrollNearLeftEdgeTriggersLoadOlder() throws {
        let repo = try makeRepo()
        try seedMinuteData(repo, start: date(2026, 8, 24, 6, 0), count: 788)
        let model = makeModel(repo, granularity: .minute, now: date(2026, 8, 24, 19, 7))

        model.scrollDidChange(to: date(2026, 8, 24, 13, 20)) // 12 min travelled <= 30%

        XCTAssertEqual(model.loadedRange?.start, date(2026, 8, 24, 7, 8))
        XCTAssertFalse(model.isViewingLatest)
    }

    func testScrollAwayFromLeftEdgeDoesNotLoad() throws {
        let repo = try makeRepo()
        try seedMinuteData(repo, start: date(2026, 8, 24, 6, 0), count: 788)
        let model = makeModel(repo, granularity: .minute, now: date(2026, 8, 24, 19, 7))

        model.scrollDidChange(to: date(2026, 8, 24, 15, 0)) // 1h52m travelled > 30%

        XCTAssertEqual(model.loadedRange?.start, date(2026, 8, 24, 13, 8))
        XCTAssertEqual(model.points.count, 360)
    }

    func testRefreshTailFollowsNewestWhenViewingLatest() throws {
        let repo = try makeRepo()
        try seedMinuteData(repo, start: date(2026, 8, 24, 6, 0), count: 788)
        let updates = PassthroughSubject<Date, Never>()
        let model = makeModel(repo, granularity: .minute, now: date(2026, 8, 24, 19, 7), updates: updates)

        try repo.record(balances: [BalanceInfo(currency: "CNY", totalBalance: 211,
                                               grantedBalance: 0, toppedUpBalance: 211)],
                        at: date(2026, 8, 24, 19, 8, 30))
        updates.send(date(2026, 8, 24, 19, 8, 30))

        XCTAssertEqual(model.loadedRange?.end, date(2026, 8, 24, 19, 9))
        XCTAssertEqual(model.points.last!.start, date(2026, 8, 24, 19, 8))
        XCTAssertEqual(model.scrollAnchor, date(2026, 8, 24, 17, 8, 30))
        XCTAssertFalse(model.hasNewData)
        XCTAssertTrue(model.isViewingLatest)
    }

    func testRefreshTailDoesNotDisturbHistoryViewing() throws {
        let repo = try makeRepo()
        try seedMinuteData(repo, start: date(2026, 8, 24, 6, 0), count: 788)
        let updates = PassthroughSubject<Date, Never>()
        let model = makeModel(repo, granularity: .minute, now: date(2026, 8, 24, 19, 7), updates: updates)

        model.scrollDidChange(to: date(2026, 8, 24, 15, 0))
        let anchor = model.scrollAnchor
        let range = model.loadedRange

        try repo.record(balances: [BalanceInfo(currency: "CNY", totalBalance: 210,
                                               grantedBalance: 0, toppedUpBalance: 210)],
                        at: date(2026, 8, 24, 19, 9))
        updates.send(date(2026, 8, 24, 19, 9))

        XCTAssertTrue(model.hasNewData)
        XCTAssertEqual(model.scrollAnchor, anchor)
        XCTAssertEqual(model.loadedRange, range)
        XCTAssertEqual(model.points.last!.start, date(2026, 8, 24, 19, 7))
        XCTAssertTrue(model.canReturnToLatest)
    }

    func testScrollToLatestReloadsAndClearsFlag() throws {
        let repo = try makeRepo()
        try seedMinuteData(repo, start: date(2026, 8, 24, 6, 0), count: 788)
        let updates = PassthroughSubject<Date, Never>()
        let model = makeModel(repo, granularity: .minute, now: date(2026, 8, 24, 19, 7), updates: updates)

        model.scrollDidChange(to: date(2026, 8, 24, 15, 0))
        try repo.record(balances: [BalanceInfo(currency: "CNY", totalBalance: 210,
                                               grantedBalance: 0, toppedUpBalance: 210)],
                        at: date(2026, 8, 24, 19, 9))
        updates.send(date(2026, 8, 24, 19, 9))
        XCTAssertTrue(model.hasNewData)

        model.scrollToLatest()

        XCTAssertFalse(model.hasNewData)
        XCTAssertTrue(model.isViewingLatest)
        XCTAssertEqual(model.points.last!.start, date(2026, 8, 24, 19, 9))
        XCTAssertEqual(model.scrollAnchor, date(2026, 8, 24, 17, 9))
    }

    func testRefreshTailResetsAfterLongGap() throws {
        let repo = try makeRepo()
        try seedMinuteData(repo, start: date(2026, 8, 24, 6, 0), count: 788)
        let updates = PassthroughSubject<Date, Never>()
        let model = makeModel(repo, granularity: .minute, now: date(2026, 8, 24, 19, 7), updates: updates)

        // Two days later: far more than one 6h page.
        try repo.record(balances: [BalanceInfo(currency: "CNY", totalBalance: 100,
                                               grantedBalance: 0, toppedUpBalance: 100)],
                        at: date(2026, 8, 26, 10, 0))
        updates.send(date(2026, 8, 26, 10, 0))

        XCTAssertEqual(model.loadedRange?.end, date(2026, 8, 26, 10, 1))
        XCTAssertEqual(model.loadedRange?.start, date(2026, 8, 26, 4, 1))
        XCTAssertEqual(model.points.last!.start, date(2026, 8, 26, 10, 0))
        XCTAssertEqual(model.scrollAnchor, date(2026, 8, 26, 8, 0))
    }

    func testMergeUpsertsByStart() {
        let a = ConsumptionPoint(start: date(2026, 8, 24, 10, 0), end: date(2026, 8, 24, 10, 1),
                                 consumed: 1, startBalance: 100, endBalance: 99)
        let b = ConsumptionPoint(start: date(2026, 8, 24, 11, 0), end: date(2026, 8, 24, 11, 1),
                                 consumed: 2, startBalance: 99, endBalance: 97)
        let aNew = ConsumptionPoint(start: date(2026, 8, 24, 10, 0), end: date(2026, 8, 24, 10, 1),
                                    consumed: 1.5, startBalance: 100, endBalance: 98.5)
        let merged = MainChartViewModel.merge([a, b], [aNew])
        XCTAssertEqual(merged.map(\.start), [a.start, b.start])
        XCTAssertEqual(merged[0].consumed, 1.5)
    }

    // MARK: - Day / month

    func testDayGranularityLoadsWholeYearAndAnchorsLatest() throws {
        let repo = try makeRepo()
        for day in 1...5 {
            try repo.record(balances: [BalanceInfo(currency: "CNY", totalBalance: 100 - Double(day),
                                                   grantedBalance: 0, toppedUpBalance: 100 - Double(day))],
                            at: date(2026, 8, 20 + day, 12, 0))
        }
        let model = makeModel(repo, granularity: .day, now: date(2026, 8, 25, 12, 0))

        XCTAssertEqual(model.points.count, 5)
        XCTAssertEqual(model.loadedRange, DateInterval(start: date(2026, 1, 1), end: date(2027, 1, 1)))
        XCTAssertFalse(model.hasMoreEarlier)
        XCTAssertEqual(model.scrollAnchor, date(2026, 8, 25, 12, 0).addingTimeInterval(-30 * 24 * 3600))
        XCTAssertFalse(model.canReturnToLatest)
    }

    func testMonthGranularityFillsBucketsForConsumedMetric() throws {
        let repo = try makeRepo()
        try repo.record(balances: [BalanceInfo(currency: "CNY", totalBalance: 99,
                                               grantedBalance: 0, toppedUpBalance: 99)],
                        at: date(2026, 8, 24, 10, 0))
        let model = makeModel(repo, granularity: .month, now: date(2026, 8, 24, 12, 0))

        XCTAssertEqual(model.points.count, 12)
        XCTAssertNil(model.loadedRange)
        XCTAssertTrue(model.isViewingLatest)
        XCTAssertFalse(model.canReturnToLatest)
    }

    func testInitialLoadWithNoDataAnchorsToNow() throws {
        let repo = try makeRepo()
        let model = makeModel(repo, granularity: .minute, now: date(2026, 8, 24, 12, 0))

        XCTAssertTrue(model.points.isEmpty)
        XCTAssertEqual(model.loadedRange, DateInterval(start: date(2026, 8, 24, 6, 1),
                                                       end: date(2026, 8, 24, 12, 1)))
        XCTAssertEqual(model.scrollAnchor, date(2026, 8, 24, 10, 0))
    }
}

extension MainChartViewModelTests {
    func testRefreshTailDoesNotDisturbDayHistoryViewing() throws {
        let repo = try makeRepo()
        for day in 1...4 {
            try repo.record(balances: [BalanceInfo(currency: "CNY", totalBalance: 100 - Double(day),
                                                   grantedBalance: 0, toppedUpBalance: 100 - Double(day))],
                            at: date(2026, 8, 20 + day, 12, 0))
        }
        let updates = PassthroughSubject<Date, Never>()
        let model = makeModel(repo, granularity: .day, now: date(2026, 8, 24, 12, 0), updates: updates)

        model.scrollDidChange(to: date(2026, 7, 1)) // far in the past
        let anchor = model.scrollAnchor
        XCTAssertFalse(model.isViewingLatest)

        try repo.record(balances: [BalanceInfo(currency: "CNY", totalBalance: 80,
                                               grantedBalance: 0, toppedUpBalance: 80)],
                        at: date(2026, 8, 25, 12, 0))
        updates.send(date(2026, 8, 25, 12, 0))

        XCTAssertTrue(model.hasNewData)
        XCTAssertEqual(model.scrollAnchor, anchor)
        XCTAssertFalse(model.isViewingLatest)
        XCTAssertTrue(model.canReturnToLatest)
    }
}
