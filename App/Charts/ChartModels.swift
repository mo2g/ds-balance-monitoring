import Foundation
import Combine

public enum ChartMetric: String, CaseIterable, Identifiable {
    case balance, consumed
    public var id: String { rawValue }
    public func title(language: ResolvedLanguage) -> String {
        Localization.string("metric.\(rawValue)", language: language)
    }
}

/// Drives the main chart window.
///
/// For the minute/hour granularities the chart is paged: it opens on the
/// newest page (newest first), and older pages are fetched only when the user
/// drags close to the left edge of the loaded data. Day is loaded in full but
/// still scrolls; month is loaded in full and does not scroll.
public final class MainChartViewModel: ObservableObject {
    @Published public var year: Int
    @Published public var currency: String?
    @Published public var granularity: AggregateGranularity = .day
    @Published public var metric: ChartMetric = .consumed

    @Published public private(set) var points: [ConsumptionPoint] = []
    @Published public private(set) var availableYears: [Int] = []
    @Published public private(set) var loadedRange: DateInterval?
    @Published public private(set) var hasMoreEarlier = false
    @Published public private(set) var isLoadingEarlier = false
    @Published public private(set) var hasNewData = false
    @Published public private(set) var isViewingLatest = true
    @Published public private(set) var loadError: String?
    @Published public var scrollAnchor: Date = Date()

    private let repository: BalanceRepository
    private let updates: AnyPublisher<Date, Never>
    private let now: () -> Date
    private var cancellables = Set<AnyCancellable>()
    /// Scroll anchor that puts the newest sample at the right edge. Used to
    /// detect "the user scrolled away" for day granularity, which loads the
    /// whole year instead of pages.
    private var latestAnchor: Date?

    public init(repository: BalanceRepository,
                updates: AnyPublisher<Date, Never> = Empty().eraseToAnyPublisher(),
                now: @escaping () -> Date = { Date() }) {
        self.repository = repository
        self.updates = updates
        self.now = now
        self.year = repository.calendar.component(.year, from: now())
        updates
            .sink { [weak self] date in self?.refreshTail(at: date) }
            .store(in: &cancellables)
        reload()
    }

    /// Whether a "回到最新" affordance should be shown.
    public var canReturnToLatest: Bool {
        hasNewData || !isViewingLatest
    }

    // MARK: - Loading

    public func reload() {
        loadInitial()
    }

    public func loadInitial() {
        do {
            loadError = nil
            hasNewData = false
            isViewingLatest = true
            isLoadingEarlier = false
            availableYears = try repository.availableYears().sorted()
            if !availableYears.isEmpty, !availableYears.contains(year) {
                year = availableYears.last!
            }
            let latest = try repository.latestTimestamp(currency: currency, year: year) ?? now()

            switch granularity {
            case .minute, .hour:
                let page = ChartPaging.newestPageRange(containing: latest, granularity: granularity,
                                                       calendar: repository.calendar)
                points = try fetchPoints(range: page)
                loadedRange = page
                hasMoreEarlier = try repository.hasSnapshotsBefore(currency: currency, year: year, before: page.start)
                let anchor = ChartPaging.anchorShowingLatest(latest: latest, granularity: granularity)
                latestAnchor = anchor
                scrollAnchor = anchor

            case .day:
                let range = yearRange
                points = try fetchPoints(range: range)
                loadedRange = range
                hasMoreEarlier = false
                let anchor = ChartPaging.anchorShowingLatest(latest: latest, granularity: .day)
                latestAnchor = anchor
                scrollAnchor = anchor

            case .month:
                points = try fetchPoints(range: nil, fillsEmptyBuckets: metric == .consumed)
                loadedRange = nil
                hasMoreEarlier = false
                latestAnchor = nil
            }
        } catch {
            points = []
            loadedRange = nil
            hasMoreEarlier = false
            loadError = errorText(error)
        }
    }

    /// Fetch and prepend the page just before the loaded window. The scroll
    /// anchor is deliberately left untouched so the visible chart stays put.
    public func loadOlder() {
        guard ChartPaging.isPaginated(granularity),
              let range = loadedRange, hasMoreEarlier, !isLoadingEarlier else { return }
        isLoadingEarlier = true
        loadError = nil
        defer { isLoadingEarlier = false }
        do {
            let previous = ChartPaging.previousPageRange(endingAt: range.start, granularity: granularity,
                                                         calendar: repository.calendar)
            let older = try fetchPoints(range: previous)
            points = Self.merge(points, older)
            loadedRange = DateInterval(start: previous.start, end: range.end)
            hasMoreEarlier = try repository.hasSnapshotsBefore(currency: currency, year: year,
                                                               before: previous.start)
        } catch {
            loadError = String(format: LanguageManager.shared.t("chart.loadOlderFailed"), errorText(error))
        }
    }

    /// Called on every scroll position change. Loads an older page when the
    /// view gets close to the left edge, and clears the "new data" flag when
    /// the user drags back to the newest end.
    public func scrollDidChange(to anchor: Date) {
        scrollAnchor = anchor
        let atRightEdge: Bool
        switch granularity {
        case .minute, .hour:
            atRightEdge = loadedRange.map {
                ChartPaging.isAtLatest(anchor: anchor, windowEnd: $0.end, granularity: granularity)
            } ?? true
        case .day:
            atRightEdge = latestAnchor.map { anchor >= $0 - 0.5 } ?? true
        case .month:
            atRightEdge = true
        }
        if atRightEdge {
            isViewingLatest = true
            if hasNewData {
                // Data arrived while the user was browsing history; resync the
                // tail now that they have scrolled back to the newest end.
                hasNewData = false
                loadInitial()
                return
            }
        } else {
            isViewingLatest = false
        }
        guard let start = loadedRange?.start else { return }
        if ChartPaging.shouldLoadOlder(anchor: anchor, windowStart: start, hasMore: hasMoreEarlier,
                                       isLoading: isLoadingEarlier, granularity: granularity) {
            loadOlder()
        }
    }

    public func scrollToLatest() {
        hasNewData = false
        loadInitial()
    }

    /// A new sample was written (fired after every successful poll).
    /// - Watching the newest end: refresh/extend the tail in place and follow
    ///   the newest sample.
    /// - Browsing history: do not move the view; just flag that newer data is
    ///   available.
    public func refreshTail(at sampleDate: Date) {
        switch granularity {
        case .day:
            // The whole year is already loaded; only re-anchor when the user
            // is actually watching the newest end, otherwise just flag it.
            if isViewingLatest {
                loadInitial()
            } else {
                hasNewData = true
            }
            return
        case .month:
            loadInitial()
            return
        case .minute, .hour:
            break
        }
        guard let range = loadedRange else {
            loadInitial()
            return
        }
        let bucketEnd = ChartPaging.exclusiveCeil(sampleDate, granularity: granularity,
                                                  calendar: repository.calendar)
        do {
            if bucketEnd > range.end {
                guard isViewingLatest else {
                    hasNewData = true
                    return
                }
                // A long sleep may skip more than a page of data; a fresh
                // initial window is cleaner than stitching a huge gap.
                if bucketEnd.timeIntervalSince(range.end) > ChartPaging.pageSize(for: granularity) {
                    loadInitial()
                    return
                }
                let extensionPoints = try fetchPoints(range: DateInterval(start: range.end, end: bucketEnd))
                points = Self.merge(points, extensionPoints)
                loadedRange = DateInterval(start: range.start, end: bucketEnd)
                hasMoreEarlier = try repository.hasSnapshotsBefore(currency: currency, year: year,
                                                                   before: range.start)
                let anchor = ChartPaging.anchorShowingLatest(latest: sampleDate, granularity: granularity)
                latestAnchor = anchor
                scrollAnchor = anchor
            } else {
                // New sample lands in a bucket that is already on screen;
                // refresh that bucket without moving the view.
                let bucketStart = ChartPaging.alignFloor(sampleDate, granularity: granularity,
                                                         calendar: repository.calendar)
                let bucketPoints = try fetchPoints(range: DateInterval(start: bucketStart, end: bucketEnd))
                points = Self.merge(points, bucketPoints)
            }
        } catch {
            loadError = String(format: LanguageManager.shared.t("chart.refreshFailed"), errorText(error))
        }
    }

    // MARK: - Helpers

    /// Merge two ascending point arrays, upserting by `start` (newer wins).
    public static func merge(_ existing: [ConsumptionPoint], _ incoming: [ConsumptionPoint]) -> [ConsumptionPoint] {
        var byStart: [Date: ConsumptionPoint] = [:]
        for point in existing { byStart[point.start] = point }
        for point in incoming { byStart[point.start] = point }
        return byStart.values.sorted { $0.start < $1.start }
    }

    private var yearRange: DateInterval? {
        guard let yearStart = repository.calendar.date(from: DateComponents(year: year)),
              let nextYearStart = repository.calendar.date(from: DateComponents(year: year + 1)) else { return nil }
        return DateInterval(start: yearStart, end: nextYearStart)
    }

    private func fetchPoints(range: DateInterval?, fillsEmptyBuckets: Bool = false) throws -> [ConsumptionPoint] {
        try repository.consumptionPoints(currency: currency, year: year, granularity: granularity,
                                         range: range, fillsEmptyBuckets: fillsEmptyBuckets)
    }

    private func errorText(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
