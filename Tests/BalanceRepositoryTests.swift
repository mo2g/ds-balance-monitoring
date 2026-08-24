import XCTest
import GRDB
@testable import DSBalanceMonitor

final class BalanceRepositoryTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return cal
    }

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    func testRecordCreatesYearTableAndComputesConsumed() throws {
        let repo = try BalanceRepository.inMemory()
        let info = BalanceInfo(currency: "CNY", totalBalance: 100, grantedBalance: 0, toppedUpBalance: 100)
        try repo.record(balances: [info], at: date(2026, 8, 24, 10, 0))
        let less = BalanceInfo(currency: "CNY", totalBalance: 97.5, grantedBalance: 0, toppedUpBalance: 97.5)
        try repo.record(balances: [less], at: date(2026, 8, 24, 10, 1))

        let rows = try repo.rawSnapshots(currency: nil, year: 2026, range: nil)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].consumed, 0, accuracy: 0.0001)
        XCTAssertFalse(rows[0].isRecharge)
        XCTAssertEqual(rows[1].consumed, 2.5, accuracy: 0.0001)
        XCTAssertFalse(rows[1].isRecharge)
    }

    func testRecordMarksRechargeWhenBalanceRises() throws {
        let repo = try BalanceRepository.inMemory()
        try repo.record(balances: [BalanceInfo(currency: "CNY", totalBalance: 10, grantedBalance: 0, toppedUpBalance: 10)],
                        at: date(2026, 8, 24, 10, 0))
        try repo.record(balances: [BalanceInfo(currency: "CNY", totalBalance: 60, grantedBalance: 0, toppedUpBalance: 60)],
                        at: date(2026, 8, 24, 10, 1))
        let rows = try repo.rawSnapshots(currency: nil, year: 2026, range: nil)
        XCTAssertTrue(rows[1].isRecharge)
        XCTAssertEqual(rows[1].consumed, 0, accuracy: 0.0001)
    }

    func testYearRoutingUsesLocalYearAndPreviousYearFallback() throws {
        let repo = try BalanceRepository.inMemory()
        // Pin the calendar to the same time zone used to build the sample
        // timestamps, so the year routing assertion is deterministic even on
        // CI runners whose system time zone is UTC.
        repo.calendar = calendar
        try repo.record(balances: [BalanceInfo(currency: "CNY", totalBalance: 50, grantedBalance: 0, toppedUpBalance: 50)],
                        at: date(2025, 12, 31, 23, 59))
        try repo.record(balances: [BalanceInfo(currency: "CNY", totalBalance: 48, grantedBalance: 0, toppedUpBalance: 48)],
                        at: date(2026, 1, 1, 0, 0))
        let y2025 = try repo.rawSnapshots(currency: nil, year: 2025, range: nil)
        let y2026 = try repo.rawSnapshots(currency: nil, year: 2026, range: nil)
        XCTAssertEqual(y2025.count, 1)
        XCTAssertEqual(y2026.count, 1)
        XCTAssertEqual(y2026[0].consumed, 2.0, accuracy: 0.0001)
        XCTAssertEqual(try repo.availableYears().sorted(), [2025, 2026])
    }

    func testUpsertSameMinuteDoesNotDuplicate() throws {
        let repo = try BalanceRepository.inMemory()
        let t = date(2026, 8, 24, 10, 0)
        try repo.record(balances: [BalanceInfo(currency: "CNY", totalBalance: 100, grantedBalance: 0, toppedUpBalance: 100)], at: t)
        try repo.record(balances: [BalanceInfo(currency: "CNY", totalBalance: 99, grantedBalance: 0, toppedUpBalance: 99)], at: t)
        let rows = try repo.rawSnapshots(currency: nil, year: 2026, range: nil)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].totalBalance, 99, accuracy: 0.0001)
    }
}

extension BalanceRepositoryTests {
    func testRangeIsHalfOpenExcludesEndIncludesStart() throws {
        let repo = try BalanceRepository.inMemory()
        repo.calendar = calendar
        for (t, v) in [
            (date(2026, 8, 24, 9, 59), 100.0),
            (date(2026, 8, 24, 10, 0), 99.0),
            (date(2026, 8, 24, 12, 0), 90.0),
            (date(2026, 8, 24, 12, 1), 89.0),
        ] {
            try repo.record(balances: [BalanceInfo(currency: "CNY", totalBalance: v,
                                                   grantedBalance: 0, toppedUpBalance: v)], at: t)
        }
        let range = DateInterval(start: date(2026, 8, 24, 10, 0), end: date(2026, 8, 24, 12, 0))
        let rows = try repo.rawSnapshots(currency: nil, year: 2026, range: range)
        XCTAssertEqual(rows.map(\.timestamp), [date(2026, 8, 24, 10, 0)])
    }

    func testLatestTimestampRespectsCurrencyAndEmptyYear() throws {
        let repo = try BalanceRepository.inMemory()
        repo.calendar = calendar
        try repo.record(balances: [BalanceInfo(currency: "CNY", totalBalance: 100,
                                               grantedBalance: 0, toppedUpBalance: 100)],
                        at: date(2026, 8, 24, 10, 0))
        try repo.record(balances: [BalanceInfo(currency: "USD", totalBalance: 20,
                                               grantedBalance: 0, toppedUpBalance: 20)],
                        at: date(2026, 8, 24, 11, 0))
        try repo.record(balances: [BalanceInfo(currency: "CNY", totalBalance: 95,
                                               grantedBalance: 0, toppedUpBalance: 95)],
                        at: date(2026, 8, 24, 12, 0))

        XCTAssertEqual(try repo.latestTimestamp(currency: nil, year: 2026), date(2026, 8, 24, 12, 0))
        XCTAssertEqual(try repo.latestTimestamp(currency: "CNY", year: 2026), date(2026, 8, 24, 12, 0))
        XCTAssertEqual(try repo.latestTimestamp(currency: "USD", year: 2026), date(2026, 8, 24, 11, 0))
        XCTAssertNil(try repo.latestTimestamp(currency: nil, year: 2025))
    }

    func testHasSnapshotsBefore() throws {
        let repo = try BalanceRepository.inMemory()
        repo.calendar = calendar
        try repo.record(balances: [BalanceInfo(currency: "CNY", totalBalance: 100,
                                               grantedBalance: 0, toppedUpBalance: 100)],
                        at: date(2026, 8, 24, 10, 0))
        try repo.record(balances: [BalanceInfo(currency: "USD", totalBalance: 20,
                                               grantedBalance: 0, toppedUpBalance: 20)],
                        at: date(2026, 8, 24, 11, 0))

        XCTAssertTrue(try repo.hasSnapshotsBefore(currency: nil, year: 2026, before: date(2026, 8, 24, 12, 0)))
        XCTAssertTrue(try repo.hasSnapshotsBefore(currency: nil, year: 2026, before: date(2026, 8, 24, 11, 0)))
        XCTAssertFalse(try repo.hasSnapshotsBefore(currency: nil, year: 2026, before: date(2026, 8, 24, 10, 0)))
        XCTAssertTrue(try repo.hasSnapshotsBefore(currency: "CNY", year: 2026, before: date(2026, 8, 24, 12, 0)))
        XCTAssertFalse(try repo.hasSnapshotsBefore(currency: "USD", year: 2026, before: date(2026, 8, 24, 11, 0)))
        XCTAssertFalse(try repo.hasSnapshotsBefore(currency: nil, year: 2025, before: date(2026, 8, 24, 12, 0)))
    }
}
