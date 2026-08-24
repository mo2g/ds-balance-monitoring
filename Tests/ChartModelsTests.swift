import XCTest
@testable import DSBalanceMonitor

final class ChartModelsTests: XCTestCase {
    func testGranularityTitles() {
        XCTAssertEqual(AggregateGranularity.minute.title(language: .zhHans), "分")
        XCTAssertEqual(AggregateGranularity.hour.title(language: .zhHans), "时")
        XCTAssertEqual(AggregateGranularity.day.title(language: .zhHans), "天")
        XCTAssertEqual(AggregateGranularity.month.title(language: .zhHans), "月")
        XCTAssertEqual(AggregateGranularity.minute.title(language: .en), "Minute")
        XCTAssertEqual(AggregateGranularity.hour.title(language: .en), "Hour")
        XCTAssertEqual(AggregateGranularity.day.title(language: .en), "Day")
        XCTAssertEqual(AggregateGranularity.month.title(language: .en), "Month")
    }

    func testChartMetricTitles() {
        XCTAssertEqual(ChartMetric.balance.title(language: .zhHans), "余额曲线")
        XCTAssertEqual(ChartMetric.consumed.title(language: .zhHans), "消耗量")
        XCTAssertEqual(ChartMetric.balance.title(language: .en), "Balance")
        XCTAssertEqual(ChartMetric.consumed.title(language: .en), "Consumption")
    }
}
