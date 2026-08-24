import SwiftUI
import Charts

struct MainChartView: View {
    @StateObject private var model: MainChartViewModel
    @State private var selectedDate: Date?
    @EnvironmentObject var language: LanguageManager

    init(repository: BalanceRepository) {
        _model = StateObject(wrappedValue: MainChartViewModel(
            repository: repository,
            updates: AppServices.shared.samplesDidChange.eraseToAnyPublisher()))
    }

    private var selectedPoint: ConsumptionPoint? {
        guard let date = selectedDate, !model.points.isEmpty else { return nil }
        return model.points.min {
            abs($0.start.timeIntervalSince(date)) < abs($1.start.timeIntervalSince(date))
        }
    }

    private var totalConsumed: Double {
        model.points.reduce(0) { $0 + $1.consumed }
    }

    private var scrollBinding: Binding<Date> {
        Binding(
            get: { model.scrollAnchor },
            set: { model.scrollDidChange(to: $0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            HStack(spacing: 16) {
                Label(String(format: language.t("chart.loadedNodes"), model.points.count),
                      systemImage: "point.3.connected.trianglepath.dotted")
                if let range = model.loadedRange, ChartPaging.isPaginated(model.granularity) {
                    Text(rangeText(range))
                        .monospacedDigit()
                }
                Spacer()
                Text(String(format: language.t("chart.loadedRangeConsumed"),
                            "\(currencySymbol)\(BalanceFormatting.formattedAmount(totalConsumed))"))
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            BalanceChart(points: model.points,
                         metric: model.metric,
                         granularity: model.granularity,
                         selectedDate: $selectedDate,
                         scrollAnchor: scrollBinding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    if model.points.isEmpty {
                        Text(language.t("chart.emptyYear"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

            pagingBar

            // Detail panel always reserves a fixed height so showing/hiding
            // node details never resizes the chart and makes it jump.
            ChartDetailPanel(point: selectedPoint,
                             metric: model.metric,
                             granularity: model.granularity,
                             currency: model.currency)
        }
        .padding()
        .onAppear { model.reload() }
    }

    private var header: some View {
        HStack {
            Picker(language.t("chart.year"), selection: $model.year) {
                ForEach(model.availableYears, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .frame(width: 120)
            .onChange(of: model.year) { _, _ in
                selectedDate = nil
                model.reload()
            }

            Picker(language.t("chart.currency"), selection: $model.currency) {
                Text(language.t("chart.allCurrencies")).tag(String?.none)
                Text("CNY").tag(String?.some("CNY"))
                Text("USD").tag(String?.some("USD"))
            }
            .frame(width: 120)
            .onChange(of: model.currency) { _, _ in
                selectedDate = nil
                model.reload()
            }

            Picker(language.t("chart.granularity"), selection: $model.granularity) {
                ForEach(AggregateGranularity.allCases) { g in
                    Text(g.title(language: language.resolved)).tag(g)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            .onChange(of: model.granularity) { _, _ in
                selectedDate = nil
                model.reload()
            }

            Picker(language.t("chart.metric"), selection: $model.metric) {
                ForEach(ChartMetric.allCases) { m in
                    Text(m.title(language: language.resolved)).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            .onChange(of: model.metric) { _, _ in
                selectedDate = nil
            }
        }
    }

    /// One fixed-height line that reports paging state and offers the
    /// "load older" / "back to latest" actions without resizing the chart.
    private var pagingBar: some View {
        HStack(spacing: 10) {
            if model.isLoadingEarlier {
                ProgressView()
                    .controlSize(.small)
                Text(language.t("chart.loadingEarlier"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let message = model.loadError {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else if model.hasMoreEarlier {
                Image(systemName: "arrow.left.circle")
                    .foregroundStyle(.secondary)
                Text(language.t("chart.scrollHint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(ChartPaging.isPaginated(model.granularity)
                     ? language.t("chart.earliestReached") : " ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if model.hasMoreEarlier, !model.isLoadingEarlier {
                Button {
                    model.loadOlder()
                } label: {
                    Label(language.t("chart.loadOlder"), systemImage: "arrow.left")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if model.canReturnToLatest {
                Button {
                    selectedDate = nil
                    model.scrollToLatest()
                } label: {
                    Label(model.hasNewData
                          ? language.t("chart.newDataBackToLatest")
                          : language.t("chart.backToLatest"),
                          systemImage: "arrow.right.to.line")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .frame(height: 28)
    }

    private var currencySymbol: String {
        guard let currency = model.currency else { return "" }
        return BalanceFormatting.currencySymbol(for: currency)
    }

    private func rangeText(_ range: DateInterval) -> String {
        let formatter = DateFormatter()
        formatter.locale = chartLocale
        switch model.granularity {
        case .minute:
            formatter.dateFormat = language.resolved == .zhHans ? "M月d日 HH:mm" : "MMM d HH:mm"
        case .hour:
            formatter.dateFormat = language.resolved == .zhHans ? "M月d日 HH:00" : "MMM d HH:00"
        case .day:
            formatter.dateFormat = language.resolved == .zhHans ? "yyyy年M月d日" : "MMM d, yyyy"
        case .month:
            formatter.dateFormat = language.resolved == .zhHans ? "yyyy年M月" : "MMM yyyy"
        }
        // Displayed end is exclusive; subtract one second so the label shows
        // the last bucket that is actually inside the range.
        let end = range.end.addingTimeInterval(-1)
        return "\(formatter.string(from: range.start)) – \(formatter.string(from: end))"
    }

    private var chartLocale: Locale {
        language.resolved == .zhHans ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
    }
}

private struct ChartDetailPanel: View {
    let point: ConsumptionPoint?
    let metric: ChartMetric
    let granularity: AggregateGranularity
    let currency: String?
    @EnvironmentObject var language: LanguageManager

    var body: some View {
        Group {
            if let point {
                ChartDetailCard(point: point, metric: metric, granularity: granularity, currency: currency)
            } else {
                Text(language.t("chart.hoverHint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 96, alignment: .top)
    }
}

private struct ChartDetailCard: View {
    let point: ConsumptionPoint
    let metric: ChartMetric
    let granularity: AggregateGranularity
    let currency: String?
    @EnvironmentObject var language: LanguageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(timeRangeText)
                    .font(.headline)
                if point.isRecharge {
                    Text(language.t("chart.includesRecharge"))
                        .font(.caption.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .foregroundStyle(.white)
                        .background(Color.orange, in: Capsule())
                }
                Spacer()
                Text(point.consumed > 0
                     ? "\(currencySymbol)\(BalanceFormatting.formattedAmount(point.consumed)) / \(granularity.title(language: language.resolved))"
                     : "—")
                    .font(.callout.bold().monospacedDigit())
                    .lineLimit(1)
                    .foregroundStyle(metric == .consumed ? .orange : .primary)
            }
            HStack(spacing: 20) {
                DetailField(title: language.t("chart.startBalance"), value: amount(point.startBalance))
                DetailField(title: language.t("chart.endBalance"), value: amount(point.endBalance))
                DetailField(title: language.t("chart.consumedInPeriod"), value: amount(point.consumed))
                if point.isRecharge {
                    DetailField(title: language.t("chart.note"), value: language.t("chart.rechargeNote"))
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.15))
        )
    }

    private func amount(_ value: Double) -> String {
        "\(currencySymbol)\(BalanceFormatting.formattedAmount(value))"
    }

    private var currencySymbol: String {
        guard let currency else { return "" }
        return BalanceFormatting.currencySymbol(for: currency)
    }

    private var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.locale = language.resolved == .zhHans
            ? Locale(identifier: "zh_CN")
            : Locale(identifier: "en_US")
        switch granularity {
        case .minute:
            formatter.dateFormat = language.resolved == .zhHans
                ? "yyyy年M月d日 HH:mm" : "MMM d, yyyy HH:mm"
            return formatter.string(from: point.start)
        case .hour:
            formatter.dateFormat = language.resolved == .zhHans
                ? "yyyy年M月d日 HH:00–HH:59" : "MMM d, yyyy HH:00–HH:59"
            return formatter.string(from: point.start)
        case .day:
            formatter.dateFormat = language.resolved == .zhHans
                ? "yyyy年M月d日" : "MMM d, yyyy"
            return formatter.string(from: point.start)
        case .month:
            formatter.dateFormat = language.resolved == .zhHans
                ? "yyyy年M月" : "MMM yyyy"
            return formatter.string(from: point.start)
        }
    }
}

private struct DetailField: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.monospacedDigit())
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}

enum MainWindowPresenter {
    private static var window: NSWindow?
    private static var windowDelegate: WindowCloser?

    static func show() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 660),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            // Programmatically created NSWindows release themselves when closed
            // by default. Disable that so the static reference never dangles,
            // and clear it via the delegate instead (see WindowCloser).
            window.isReleasedWhenClosed = false
            let delegate = WindowCloser { MainWindowPresenter.window = nil }
            windowDelegate = delegate
            window.delegate = delegate
            window.title = AppServices.shared.language.t("window.title")
            window.contentView = NSHostingView(rootView: MainChartView(repository: AppServices.shared.repository)
                .environmentObject(AppServices.shared.language))
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// NSWindow.delegate is a weak reference, so keep a strong reference here and
/// reset MainWindowPresenter.window when the window is closed. The window is
/// recreated on the next open, avoiding any use-after-free.
private final class WindowCloser: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
