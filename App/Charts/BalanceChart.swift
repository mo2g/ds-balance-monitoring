import SwiftUI
import Charts

struct BalanceChart: View {
    let points: [ConsumptionPoint]
    let metric: ChartMetric
    let granularity: AggregateGranularity
    @Binding var selectedDate: Date?
    @Binding var scrollAnchor: Date
    @EnvironmentObject var language: LanguageManager

    private var selectedPoint: ConsumptionPoint? {
        guard let date = selectedDate, !points.isEmpty else { return nil }
        return points.min {
            abs($0.start.timeIntervalSince(date)) < abs($1.start.timeIntervalSince(date))
        }
    }

    private var selectionY: Double? {
        guard let point = selectedPoint else { return nil }
        return metric == .consumed ? point.consumed : point.endBalance
    }

    var body: some View {
        Chart {
            ForEach(points, id: \.start) { point in
                if metric == .consumed {
                    BarMark(x: .value("时间", point.start, unit: granularity.calendarComponent),
                            y: .value("消耗", point.consumed))
                        .foregroundStyle(point.isRecharge
                                         ? AnyShapeStyle(Color.orange.opacity(0.55))
                                         : AnyShapeStyle(Color.accentColor.gradient))
                } else {
                    AreaMark(x: .value("时间", point.start, unit: granularity.calendarComponent),
                             yStart: .value("余额", 0),
                             yEnd: .value("余额", point.endBalance))
                        .foregroundStyle(Color.accentColor.opacity(0.25).gradient)
                    LineMark(x: .value("时间", point.start, unit: granularity.calendarComponent),
                             y: .value("余额", point.endBalance))
                        .foregroundStyle(Color.accentColor)
                }
            }

            // Snap the rule and point to the actual node so the UI steps
            // cleanly from node to node instead of tracking the pointer.
            if let point = selectedPoint {
                RuleMark(x: .value("选中时间", point.start, unit: granularity.calendarComponent))
                    .foregroundStyle(Color.primary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }

            if let point = selectedPoint, let y = selectionY {
                PointMark(x: .value("选中时间", point.start, unit: granularity.calendarComponent),
                          y: .value(metric == .consumed ? "消耗" : "余额", y))
                    .symbolSize(110)
                    .foregroundStyle(Color.orange)
            }
        }
        .chartYAxisLabel(metric == .consumed
                         ? language.t("chart.axisConsumption")
                         : language.t("chart.axisBalance"), position: .leading)
        .chartXSelection(value: $selectedDate)
        // Draw the value bubble in an overlay: chart annotations participate in
        // the plot layout and can nudge the chart left/right when they appear
        // near the edges. The overlay never affects the chart's geometry.
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let point = selectedPoint, let y = selectionY,
                   let pos = proxy.position(for: (x: point.start, y: y)) {
                    let bubble = Text(metric == .consumed
                                      ? BalanceFormatting.formattedAmount(point.consumed)
                                      : BalanceFormatting.formattedAmount(point.endBalance))
                        .font(.caption.bold().monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.secondary.opacity(0.2)))
                    bubble
                        .position(x: min(max(pos.x, 24), geometry.size.width - 24),
                                  y: max(14, pos.y - 18))
                }
            }
        }
        .modifier(ScrollingModifier(granularity: granularity, scrollAnchor: $scrollAnchor))
    }
}

private struct ScrollingModifier: ViewModifier {
    let granularity: AggregateGranularity
    @Binding var scrollAnchor: Date

    @ViewBuilder
    func body(content: Content) -> some View {
        switch granularity {
        case .minute:
            content
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: 3600 * 2)
                .chartScrollPosition(x: $scrollAnchor)
        case .hour:
            content
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: 3600 * 24)
                .chartScrollPosition(x: $scrollAnchor)
        case .day:
            content
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: 3600 * 24 * 30)
                .chartScrollPosition(x: $scrollAnchor)
        case .month:
            content
        }
    }
}
