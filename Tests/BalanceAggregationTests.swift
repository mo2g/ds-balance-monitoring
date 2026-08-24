import XCTest
@testable import DSBalanceMonitor

final class BalanceAggregationTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return cal
    }
    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    private func makeRepo() throws -> BalanceRepository {
        let repo = try BalanceRepository.inMemory()
        repo.calendar = calendar
        let feed: [(Date, Double)] = [
            (date(2026, 8, 24, 10, 0), 100),
            (date(2026, 8, 24, 10, 15), 98),
            (date(2026, 8, 24, 11, 45), 95),
            (date(2026, 8, 25, 9, 0), 150),
            (date(2026, 8, 25, 9, 30), 149),
        ]
        for (t, v) in feed {
            try repo.record(balances: [BalanceInfo(currency: "CNY", totalBalance: v, grantedBalance: 0, toppedUpBalance: v)], at: t)
        }
        return repo
    }

    func testHourlyConsumptionSumsDeltas() throws {
        let repo = try makeRepo()
        let points = try repo.consumptionPoints(currency: "CNY", year: 2026, granularity: .hour, range: nil)
        XCTAssertEqual(points.map(\.consumed), [2.0, 3.0, 1.0])
        XCTAssertEqual(points[0].start, date(2026, 8, 24, 10, 0))
        XCTAssertEqual(points[1].start, date(2026, 8, 24, 11, 0))
        XCTAssertEqual(points[2].start, date(2026, 8, 25, 9, 0))
    }

    func testDailyConsumptionExcludesRechargeAndAddsRechargePoint() throws {
        let repo = try makeRepo()
        let points = try repo.consumptionPoints(currency: "CNY", year: 2026, granularity: .day, range: nil)
        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points[0].consumed, 5.0, accuracy: 0.0001)
        XCTAssertEqual(points[0].endBalance, 95.0, accuracy: 0.0001)
        XCTAssertEqual(points[1].consumed, 1.0, accuracy: 0.0001)
        XCTAssertEqual(points[1].startBalance, 150.0, accuracy: 0.0001)
        XCTAssertFalse(points[0].isRecharge)
        XCTAssertTrue(points[1].isRecharge)
    }

    func testMonthGranularity() throws {
        let repo = try makeRepo()
        let points = try repo.consumptionPoints(currency: "CNY", year: 2026, granularity: .month, range: nil)
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].consumed, 6.0, accuracy: 0.0001)
    }

    func testMinuteGranularityReturnsOnePointPerSample() throws {
        let repo = try makeRepo()
        let points = try repo.consumptionPoints(currency: "CNY", year: 2026, granularity: .minute, range: nil)
        XCTAssertEqual(points.count, 5)
    }

    func testRangeFilterLimitsPoints() throws {
        let repo = try makeRepo()
        let range = DateInterval(start: date(2026, 8, 24, 10, 0), end: date(2026, 8, 24, 12, 0))
        let points = try repo.consumptionPoints(currency: "CNY", year: 2026, granularity: .hour, range: range)
        XCTAssertEqual(points.map(\.consumed), [2.0, 3.0])
    }
}

extension BalanceAggregationTests {
    func testMonthGranularityFillsAllMonthsWhenRequested() throws {
        let repo = try makeRepo()
        let points = try repo.consumptionPoints(currency: "CNY", year: 2026, granularity: .month,
                                                range: nil, fillsEmptyBuckets: true)
        XCTAssertEqual(points.count, 12)
        let august = points.first { calendar.component(.month, from: $0.start) == 8 }
        XCTAssertEqual(august!.consumed, 6.0, accuracy: 0.0001)
        let january = points.first { calendar.component(.month, from: $0.start) == 1 }
        XCTAssertEqual(january!.consumed, 0.0, accuracy: 0.0001)
    }
}
