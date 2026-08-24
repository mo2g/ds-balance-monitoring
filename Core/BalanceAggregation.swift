import Foundation

public enum AggregateGranularity: String, CaseIterable, Identifiable {
    case minute, hour, day, month

    public var id: String { rawValue }

    public func title(language: ResolvedLanguage) -> String {
        Localization.string("granularity.\(rawValue)", language: language)
    }

    public var calendarComponent: Calendar.Component {
        switch self {
        case .minute: return .minute
        case .hour: return .hour
        case .day: return .day
        case .month: return .month
        }
    }
}

public struct ConsumptionPoint: Equatable {
    public var start: Date
    public var end: Date
    public var consumed: Double
    public var startBalance: Double
    public var endBalance: Double
    public var isRecharge: Bool

    public init(start: Date, end: Date, consumed: Double, startBalance: Double, endBalance: Double,
                isRecharge: Bool = false) {
        self.start = start
        self.end = end
        self.consumed = consumed
        self.startBalance = startBalance
        self.endBalance = endBalance
        self.isRecharge = isRecharge
    }
}

extension BalanceRepository {
    public func consumptionPoints(currency: String?, year: Int, granularity: AggregateGranularity,
                                  range: DateInterval?, fillsEmptyBuckets: Bool = false) throws -> [ConsumptionPoint] {
        let snapshots = try rawSnapshots(currency: currency, year: year, range: range)
        var buckets: [Date: [BalanceSnapshot]] = [:]
        for snapshot in snapshots {
            guard let interval = calendar.dateInterval(of: granularity.calendarComponent, for: snapshot.timestamp) else { continue }
            buckets[interval.start, default: []].append(snapshot)
        }
        let starts: [Date]
        if fillsEmptyBuckets, granularity == .month {
            starts = (1...12).compactMap { month in
                calendar.date(from: DateComponents(year: year, month: month))
            }
        } else {
            starts = buckets.keys.sorted()
        }
        return starts.map { start in
            guard let values = buckets[start], !values.isEmpty else {
                return ConsumptionPoint(start: start,
                                        end: calendar.dateInterval(of: granularity.calendarComponent, for: start)!.end,
                                        consumed: 0, startBalance: 0, endBalance: 0)
            }
            let sorted = values.sorted { $0.timestamp < $1.timestamp }
            let consumed = sorted.reduce(0.0) { $0 + $1.consumed }
            let recharged = sorted.contains { $0.isRecharge }
            return ConsumptionPoint(start: start,
                                    end: calendar.dateInterval(of: granularity.calendarComponent, for: start)!.end,
                                    consumed: consumed,
                                    startBalance: sorted.first!.totalBalance,
                                    endBalance: sorted.last!.totalBalance,
                                    isRecharge: recharged)
        }
    }
}
