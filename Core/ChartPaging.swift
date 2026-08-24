import Foundation

/// Pure helpers for the chart's "newest first + paged loading" behaviour.
///
/// Window/range conventions:
/// - All page and query ranges are half-open `[start, end)`.
/// - Page boundaries are aligned to the granularity bucket so a bucket is
///   never split across two pages.
/// - `anchor` is the left edge of the currently visible chart window, which is
///   exactly the value bound to Swift Charts' `chartScrollPosition(x:)`.
public enum ChartPaging {
    /// Number of seconds loaded per page; `0` means the granularity is loaded
    /// in full and never paged.
    public static func pageSize(for granularity: AggregateGranularity) -> TimeInterval {
        switch granularity {
        case .minute: return 3600 * 6
        case .hour: return 3600 * 24 * 7
        case .day, .month: return 0
        }
    }

    /// Width of the visible chart window in seconds.
    public static func visibleDomainLength(for granularity: AggregateGranularity) -> TimeInterval {
        switch granularity {
        case .minute: return 3600 * 2
        case .hour: return 3600 * 24
        case .day: return 3600 * 24 * 30
        case .month: return 0
        }
    }

    /// Fraction of the visible window that must remain before the left edge
    /// triggers loading an older page.
    public static var loadOlderThreshold: TimeInterval { 0.3 }

    public static func isPaginated(_ granularity: AggregateGranularity) -> Bool {
        pageSize(for: granularity) > 0
    }

    public static func alignFloor(_ date: Date, granularity: AggregateGranularity, calendar: Calendar) -> Date {
        calendar.dateInterval(of: granularity.calendarComponent, for: date)?.start ?? date
    }

    /// Smallest bucket-aligned instant `>= date`. A date exactly on a bucket
    /// boundary is already aligned and returned unchanged. Used for page
    /// contiguity, where the shared boundary must be excluded from the older
    /// page and included in the newer one.
    public static func alignCeil(_ date: Date, granularity: AggregateGranularity, calendar: Calendar) -> Date {
        guard let bucket = calendar.dateInterval(of: granularity.calendarComponent, for: date) else { return date }
        return date == bucket.start ? bucket.start : bucket.end
    }

    /// End (exclusive) of the bucket containing `date`, so that a sample that
    /// sits exactly on a bucket boundary is still included in a half-open
    /// range ending here.
    public static func exclusiveCeil(_ date: Date, granularity: AggregateGranularity, calendar: Calendar) -> Date {
        calendar.dateInterval(of: granularity.calendarComponent, for: date)?.end ?? date
    }

    /// The newest page containing `latest`:
    /// `[exclusiveCeil(latest) - pageSize, exclusiveCeil(latest))`.
    public static func newestPageRange(containing latest: Date, granularity: AggregateGranularity,
                                       calendar: Calendar) -> DateInterval {
        let end = exclusiveCeil(latest, granularity: granularity, calendar: calendar)
        return DateInterval(start: end.addingTimeInterval(-pageSize(for: granularity)), end: end)
    }

    /// The page immediately before `end` (exclusive): `[end - pageSize, end)`,
    /// with `end` aligned up so pages stay contiguous and buckets stay whole.
    public static func previousPageRange(endingAt end: Date, granularity: AggregateGranularity,
                                         calendar: Calendar) -> DateInterval {
        let alignedEnd = alignCeil(end, granularity: granularity, calendar: calendar)
        return DateInterval(start: alignedEnd.addingTimeInterval(-pageSize(for: granularity)), end: alignedEnd)
    }

    /// Default scroll anchor that puts `latest` at the right edge of the view.
    public static func anchorShowingLatest(latest: Date, granularity: AggregateGranularity) -> Date {
        latest.addingTimeInterval(-visibleDomainLength(for: granularity))
    }

    /// Whether the view has scrolled close enough to the left edge of the
    /// loaded data that an older page should be fetched.
    public static func shouldLoadOlder(anchor: Date, windowStart: Date, hasMore: Bool, isLoading: Bool,
                                       granularity: AggregateGranularity) -> Bool {
        guard isPaginated(granularity), hasMore, !isLoading else { return false }
        let length = visibleDomainLength(for: granularity)
        guard length > 0 else { return false }
        let travelled = anchor.timeIntervalSince(windowStart)
        guard travelled >= 0 else { return true }
        return travelled <= length * loadOlderThreshold
    }

    /// Whether the visible window currently ends at (or past) the right edge of
    /// the loaded data, i.e. the user is watching the newest samples.
    public static func isAtLatest(anchor: Date, windowEnd: Date, granularity: AggregateGranularity) -> Bool {
        anchor.addingTimeInterval(visibleDomainLength(for: granularity)) >= windowEnd - 0.5
    }
}
