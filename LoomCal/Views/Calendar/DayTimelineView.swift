import SwiftUI

/// Scrollable 24-hour timeline for a single day.
/// Displays hour grid lines, absolute-positioned event cards, and the now indicator.
/// All-day events appear in the banner strip above.
struct DayTimelineView: View {
    /// Timed (non-all-day) events for this day — pre-filtered by CalendarViewModel
    let events: [LoomEvent]
    /// All-day events for this day — pre-filtered by CalendarViewModel
    let allDayEvents: [LoomEvent]
    /// Callback when an event card is tapped
    var onEventTap: (LoomEvent) -> Void = { _ in }
    /// Callback when an event card is drag-moved. Receives (event, pointsDelta).
    var onEventDragMove: ((LoomEvent, CGFloat) -> Void)?

    // MARK: - Layout Constants

    /// Points per hour — 60 pt = 1 pt per minute. 24 * 60 = 1440 pt total.
    let pointsPerHour: CGFloat = 60.0
    /// Fixed leading width for hour labels
    private let labelWidth: CGFloat = 50.0

    private var totalHeight: CGFloat { 24 * pointsPerHour }

    // MARK: - Scroll Position

    @State private var scrollPosition = ScrollPosition(y: 0)

    // MARK: - Width from parent

    @State private var availableWidth: CGFloat = 0

    // MARK: - Time Formatter

    private static let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h a"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // All-day events banner (collapses to zero height when empty)
            AllDayBannerView(events: allDayEvents)

            // Measure available width OUTSIDE the ScrollView
            Color.clear
                .frame(height: 0)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: WidthPreferenceKey.self, value: geo.size.width)
                    }
                )
                .onPreferenceChange(WidthPreferenceKey.self) { width in
                    availableWidth = width
                }

            // Scrollable 24-hour timeline — no GeometryReader inside
            ScrollView(.vertical) {
                ZStack(alignment: .topLeading) {
                    let contentWidth = max(availableWidth - labelWidth, 0)

                    // Hour grid lines + labels
                    ForEach(0..<24, id: \.self) { hour in
                        hourRow(hour: hour, contentWidth: contentWidth)
                    }

                    // Now indicator (updates every 60 seconds via TimelineView)
                    nowIndicator(contentWidth: contentWidth)

                    // Event cards (absolutely positioned)
                    eventCards(contentWidth: contentWidth)
                }
                .frame(width: availableWidth, height: totalHeight)
            }
            .scrollPosition($scrollPosition)
            .onAppear {
                let yOffset = max(0, currentTimeYOffset() - 100)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scrollPosition = ScrollPosition(y: yOffset)
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func hourRow(hour: Int, contentWidth: CGFloat) -> some View {
        let yOffset = CGFloat(hour) * pointsPerHour

        // Hour label
        Text(hourLabel(for: hour))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(width: labelWidth, alignment: .trailing)
            .padding(.trailing, 6)
            .offset(y: yOffset - 7)

        // Grid line
        Rectangle()
            .fill(Color.gray.opacity(0.15))
            .frame(width: contentWidth, height: 0.5)
            .offset(x: labelWidth, y: yOffset)
    }

    @ViewBuilder
    private func nowIndicator(contentWidth: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let yOffset = currentTimeYOffset(for: context.date)

            ZStack(alignment: .leading) {
                // Red dot
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .offset(x: labelWidth - 4, y: yOffset - 4)

                // Red line
                Rectangle()
                    .fill(Color.red)
                    .frame(width: contentWidth, height: 1.5)
                    .offset(x: labelWidth, y: yOffset)
            }
        }
    }

    @ViewBuilder
    private func eventCards(contentWidth: CGFloat) -> some View {
        let layoutEvents = computeLayout(for: events, contentWidth: contentWidth)

        ForEach(layoutEvents, id: \.event._id) { item in
            TimelineEventCard(
                event: item.event,
                onTap: { onEventTap(item.event) },
                onDragMove: { delta in
                    onEventDragMove?(item.event, delta)
                }
            )
            .frame(width: item.width, height: max(item.height, 24))
            .offset(x: labelWidth + item.xOffset, y: item.yOffset)
        }
    }

    // MARK: - Layout Computation

    private struct EventLayoutItem {
        let event: LoomEvent
        let yOffset: CGFloat
        let height: CGFloat
        let xOffset: CGFloat
        let width: CGFloat
    }

    /// Greedy column-assignment algorithm for overlapping events.
    private func computeLayout(for events: [LoomEvent], contentWidth: CGFloat) -> [EventLayoutItem] {
        let sorted = events.sorted { $0.start < $1.start }

        var columnEnds: [Int] = []
        var assignments: [(event: LoomEvent, column: Int)] = []

        for event in sorted {
            let eventStart = event.start
            let eventEnd = event.start + event.duration * 60 * 1000

            if let col = columnEnds.firstIndex(where: { $0 <= eventStart }) {
                columnEnds[col] = eventEnd
                assignments.append((event: event, column: col))
            } else {
                let col = columnEnds.count
                columnEnds.append(eventEnd)
                assignments.append((event: event, column: col))
            }
        }

        return assignments.map { item in
            let event = item.event
            let col = item.column

            let eventStart = event.start
            let eventEnd = event.start + event.duration * 60 * 1000

            let overlappingColumnCount = assignments
                .filter { other in
                    let otherStart = other.event.start
                    let otherEnd = other.event.start + other.event.duration * 60 * 1000
                    return otherStart < eventEnd && otherEnd > eventStart
                }
                .map { $0.column }
                .max()
                .map { $0 + 1 } ?? 1

            let columnWidth = (contentWidth - 4) / CGFloat(overlappingColumnCount)
            let xOffset = CGFloat(col) * columnWidth + 2
            let yOffset = yOffsetForStart(event.start)
            let height = max(CGFloat(event.duration) / 60.0 * pointsPerHour, 24)

            return EventLayoutItem(
                event: event,
                yOffset: yOffset,
                height: height,
                xOffset: xOffset,
                width: columnWidth - 2
            )
        }
    }

    // MARK: - Helpers

    private func yOffsetForStart(_ startMs: Int) -> CGFloat {
        let date = Date(timeIntervalSince1970: TimeInterval(startMs) / 1000)
        return yOffset(for: date)
    }

    private func yOffset(for date: Date) -> CGFloat {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return CGFloat(hour * 60 + minute) / 60.0 * pointsPerHour
    }

    private func currentTimeYOffset(for date: Date = Date()) -> CGFloat {
        yOffset(for: date)
    }

    private func hourLabel(for hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        components.second = 0
        let date = Calendar.current.date(from: components) ?? Date()
        return Self.hourFormatter.string(from: date)
    }
}

// MARK: - Width Preference Key

private struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    DayTimelineView(events: [], allDayEvents: [])
}
