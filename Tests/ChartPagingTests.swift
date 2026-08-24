import XCTest
@testable import DSBalanceMonitor

final class ChartPagingTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return cal
    }

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0, _ s: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
    }

    func testPageAndVisibleLengths() {
        XCTAssertEqual(ChartPaging.pageSize(for: .minute), 6 * 3600)
        XCTAssertEqual(ChartPaging.visibleDomainLength(for: .minute), 2 * 3600)
        XCTAssertEqual(ChartPaging.pageSize(for: .hour), 7 * 24 * 3600)
        XCTAssertEqual(ChartPaging.visibleDomainLength(for: .hour), 24 * 3600)
        XCTAssertEqual(ChartPaging.pageSize(for: .day), 0)
        XCTAssertEqual(ChartPaging.visibleDomainLength(for: .day), 30 * 24 * 3600)
        XCTAssertEqual(ChartPaging.pageSize(for: .month), 0)
        XCTAssertEqual(ChartPaging.visibleDomainLength(for: .month), 0)
    }

    func testAlignFloorAndCeilForMinute() {
        let sample = date(2026, 8, 24, 10, 7, 34)
        XCTAssertEqual(ChartPaging.alignFloor(sample, granularity: .minute, calendar: calendar),
                       date(2026, 8, 24, 10, 7))
        XCTAssertEqual(ChartPaging.alignCeil(sample, granularity: .minute, calendar: calendar),
                       date(2026, 8, 24, 10, 8))
        let exact = date(2026, 8, 24, 10, 7)
        XCTAssertEqual(ChartPaging.alignCeil(exact, granularity: .minute, calendar: calendar), exact)
    }

    func testAlignFloorAndCeilForHour() {
        let sample = date(2026, 8, 24, 10, 7, 34)
        XCTAssertEqual(ChartPaging.alignFloor(sample, granularity: .hour, calendar: calendar),
                       date(2026, 8, 24, 10, 0))
        XCTAssertEqual(ChartPaging.alignCeil(sample, granularity: .hour, calendar: calendar),
                       date(2026, 8, 24, 11, 0))
        let exact = date(2026, 8, 24, 10, 0)
        XCTAssertEqual(ChartPaging.alignCeil(exact, granularity: .hour, calendar: calendar), exact)
    }

    func testNewestPageRangeContainsLatestAndAlignsEnd() {
        let latest = date(2026, 8, 24, 19, 7, 34)
        let range = ChartPaging.newestPageRange(containing: latest, granularity: .minute, calendar: calendar)
        XCTAssertEqual(range.end, date(2026, 8, 24, 19, 8))
        XCTAssertEqual(range.start, date(2026, 8, 24, 13, 8))
        XCTAssertTrue(range.contains(latest))
        XCTAssertEqual(range.duration, 6 * 3600)
    }

    func testPreviousPageRangesAreContiguousHalfOpen() {
        let end = date(2026, 8, 24, 13, 8)
        let previous = ChartPaging.previousPageRange(endingAt: end, granularity: .minute, calendar: calendar)
        XCTAssertEqual(previous.end, end)
        XCTAssertEqual(previous.start, date(2026, 8, 24, 7, 8))
        XCTAssertEqual(previous.duration, 6 * 3600)
    }

    func testShouldLoadOlderOnlyNearLeftEdge() {
        let windowStart = date(2026, 8, 24, 13, 8)
        let length = ChartPaging.visibleDomainLength(for: .minute)

        // Exactly at the 30% point -> load.
        let atThreshold = windowStart.addingTimeInterval(length * 0.3)
        XCTAssertTrue(ChartPaging.shouldLoadOlder(anchor: atThreshold, windowStart: windowStart,
                                                  hasMore: true, isLoading: false, granularity: .minute))
        // Just past it -> no load.
        let past = windowStart.addingTimeInterval(length * 0.3 + 60)
        XCTAssertFalse(ChartPaging.shouldLoadOlder(anchor: past, windowStart: windowStart,
                                                   hasMore: true, isLoading: false, granularity: .minute))
        // No earlier data -> never load.
        XCTAssertFalse(ChartPaging.shouldLoadOlder(anchor: atThreshold, windowStart: windowStart,
                                                   hasMore: false, isLoading: false, granularity: .minute))
        // Already loading -> don't re-enter.
        XCTAssertFalse(ChartPaging.shouldLoadOlder(anchor: atThreshold, windowStart: windowStart,
                                                   hasMore: true, isLoading: true, granularity: .minute))
    }

    func testShouldLoadOlderDisabledForFullGranularities() {
        let anchor = date(2026, 8, 24, 10, 0)
        XCTAssertFalse(ChartPaging.shouldLoadOlder(anchor: anchor, windowStart: anchor,
                                                   hasMore: true, isLoading: false, granularity: .day))
        XCTAssertFalse(ChartPaging.shouldLoadOlder(anchor: anchor, windowStart: anchor,
                                                   hasMore: true, isLoading: false, granularity: .month))
    }

    func testIsAtLatest() {
        let end = date(2026, 8, 24, 19, 8)
        let anchor = end.addingTimeInterval(-2 * 3600)
        XCTAssertTrue(ChartPaging.isAtLatest(anchor: anchor, windowEnd: end, granularity: .minute))
        let away = anchor.addingTimeInterval(-10 * 60)
        XCTAssertFalse(ChartPaging.isAtLatest(anchor: away, windowEnd: end, granularity: .minute))
    }

    func testAnchorShowingLatest() {
        let latest = date(2026, 8, 24, 19, 7, 34)
        let anchor = ChartPaging.anchorShowingLatest(latest: latest, granularity: .minute)
        XCTAssertEqual(anchor, latest.addingTimeInterval(-2 * 3600))
    }
}

extension ChartPagingTests {
    func testNewestPageRangeIncludesSampleOnBoundary() {
        let latest = date(2026, 8, 24, 19, 7) // exactly on a minute boundary
        let range = ChartPaging.newestPageRange(containing: latest, granularity: .minute, calendar: calendar)
        XCTAssertEqual(range.end, date(2026, 8, 24, 19, 8))
        XCTAssertTrue(range.contains(latest))
        XCTAssertEqual(range.start, date(2026, 8, 24, 13, 8))
    }

    func testExclusiveCeilIsAlwaysAfterDate() {
        let boundary = date(2026, 8, 24, 19, 7)
        let mid = date(2026, 8, 24, 19, 7, 30)
        XCTAssertEqual(ChartPaging.exclusiveCeil(boundary, granularity: .minute, calendar: calendar),
                       date(2026, 8, 24, 19, 8))
        XCTAssertEqual(ChartPaging.exclusiveCeil(mid, granularity: .minute, calendar: calendar),
                       date(2026, 8, 24, 19, 8))
        XCTAssertEqual(ChartPaging.exclusiveCeil(date(2026, 8, 24, 19, 0), granularity: .hour, calendar: calendar),
                       date(2026, 8, 24, 20, 0))
    }
}
