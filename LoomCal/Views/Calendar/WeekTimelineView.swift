import SwiftUI

/// 7-column week timeline view.
/// Shows all days in the week containing viewModel.selectedDate.
/// Each column has a day header and a mini vertical timeline with event cards.
/// Tapping an event triggers onEventTap callback for detail sheet presentation.
struct WeekTimelineView: View {
    @ObservedObject var viewModel: CalendarViewModel
    var onEventTap: (LoomEvent) -> Void = { _ in }

    // MARK: - Layout Constants

    /// Points per hour in week view — smaller than day view to fit 7 columns.
    let pointsPerHour: CGFloat = 50.0
    /// Width of the leading time-label gutter (shared across all columns).
    private let gutterWidth: CGFloat = 35.0

    private var totalHeight: CGFloat { 24 * pointsPerHour }

    // MARK: - Time Formatter

    private static let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h a"   // "2 PM", "12 AM" — major hours
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"   // "Mon", "Tue"
        return f
    }()

    // MARK: - Week Dates

    /// The 7 dates of the week containing viewModel.selectedDate.
    private var weekDates: [Date] {
        let calendar = Calendar.current
        // Get the start of the week for selectedDate
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: viewModel.selectedDate) else {
            return []
        }
        let weekStart = weekInterval.start
        return (0..<7).compactMap { day in
            calendar.date(byAdding: .day, value: day, to: weekStart)
        }
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let columnWidth = (geometry.size.width - gutterWidth) / 7

            VStack(spacing: 0) {
                // Day headers row
                HStack(spacing: 0) {
                    // Gutter spacer
                    Spacer().frame(width: gutterWidth)

                    ForEach(weekDates, id: \.self) { date in
                        dayHeader(for: date, width: columnWidth)
                    }
                }
                .background(Color(.systemBackground))

                Divider()

                // Scrollable timeline
                ScrollView(.vertical) {
                    ZStack(alignment: .topLeading) {
                        // Time label gutter + horizontal grid lines
                        ForEach(0..<24, id: \.self) { hour in
                            // Only show labels every 2 hours to reduce clutter
                            if hour % 2 == 0 {
                                hourLabel(hour: hour, totalWidth: geometry.size.width)
                            }
                            hourGridLine(hour: hour, totalWidth: geometry.size.width)
                        }

                        // Now indicator spanning all 7 columns
                        nowIndicator(totalWidth: geometry.size.width)

                        // 7 day columns with events
                        HStack(spacing: 0) {
                            // Gutter
                            Spacer().frame(width: gutterWidth)

                            ForEach(weekDates, id: \.self) { date in
                                dayColumn(for: date, width: columnWidth)
                            }
                        }
                    }
                    .frame(width: geometry.size.width, height: totalHeight)
                }
            }
        }
    }

    // MARK: - Day Header

    @ViewBuilder
    private func dayHeader(for date: Date, width: CGFloat) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: viewModel.selectedDate)
        let dayNum = calendar.component(.day, from: date)
        let dayName = Self.dayFormatter.string(from: date)

        VStack(spacing: 2) {
            Text(dayName)
                .font(.caption2)
                .foregroundStyle(isToday ? .blue : .secondary)

            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue : Color.clear)
                    .frame(width: 26, height: 26)

                Text("\(dayNum)")
                    .font(.caption)
                    .fontWeight(isToday || isSelected ? .semibold : .regular)
                    .foregroundStyle(
                        isSelected ? .white :
                        isToday ? .blue : .primary
                    )
            }
        }
        .frame(width: width)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedDate = date
        }
    }

    // MARK: - Hour Label

    @ViewBuilder
    private func hourLabel(hour: Int, totalWidth: CGFloat) -> some View {
        let yOffset = CGFloat(hour) * pointsPerHour

        Text(hourLabelText(for: hour))
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
            .frame(width: gutterWidth - 4, alignment: .trailing)
            .offset(y: yOffset - 6)
    }

    // MARK: - Hour Grid Line

    @ViewBuilder
    private func hourGridLine(hour: Int, totalWidth: CGFloat) -> some View {
        let yOffset = CGFloat(hour) * pointsPerHour

        Rectangle()
            .fill(Color(.systemGray5))
            .frame(width: totalWidth - gutterWidth, height: 0.5)
            .offset(x: gutterWidth, y: yOffset)
    }

    // MARK: - Now Indicator

    @ViewBuilder
    private func nowIndicator(totalWidth: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let yOffset = yOffset(for: context.date)

            ZStack(alignment: .leading) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                    .offset(x: gutterWidth - 3, y: yOffset - 3)

                Rectangle()
                    .fill(Color.red)
                    .frame(width: totalWidth - gutterWidth, height: 1.5)
                    .offset(x: gutterWidth, y: yOffset)
            }
        }
    }

    // MARK: - Day Column

    @ViewBuilder
    private func dayColumn(for date: Date, width: CGFloat) -> some View {
        let events = viewModel.timedEvents(for: date)

        ZStack(alignment: .topLeading) {
            // Vertical separator between columns
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(width: 0.5)
                .frame(maxHeight: .infinity, alignment: .leading)

            // Event bars/cards
            ForEach(events, id: \._id) { event in
                weekEventView(event: event, columnWidth: width)
            }
        }
        .frame(width: width, height: totalHeight)
        .clipped()
    }

    // MARK: - Week Event View

    @ViewBuilder
    private func weekEventView(event: LoomEvent, columnWidth: CGFloat) -> some View {
        let yPos = yOffsetForStart(event.start)
        let eventHeight = max(CGFloat(event.duration) / 60.0 * pointsPerHour, 18)

        // For narrow columns (<60pt), show a solid color bar only (no text).
        // For wider columns, show abbreviated title.
        let isNarrow = columnWidth < 60

        Button(action: { onEventTap(event) }) {
            if isNarrow {
                // Narrow column: colored bar only
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.blue.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.blue, lineWidth: 0.5)
                    )
            } else {
                // Wider column: colored bar with abbreviated title
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.blue)
                        .frame(width: 3)

                    Text(event.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 2)

                    Spacer(minLength: 0)
                }
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.blue.opacity(0.15))
                )
            }
        }
        .buttonStyle(.plain)
        .frame(width: columnWidth - 2, height: eventHeight)
        .offset(x: 1, y: yPos)
    }

    // MARK: - Helpers

    private func yOffset(for date: Date) -> CGFloat {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return CGFloat(hour * 60 + minute) / 60.0 * pointsPerHour
    }

    private func yOffsetForStart(_ startMs: Int) -> CGFloat {
        let date = Date(timeIntervalSince1970: TimeInterval(startMs) / 1000)
        return yOffset(for: date)
    }

    private func hourLabelText(for hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        components.second = 0
        let date = Calendar.current.date(from: components) ?? Date()
        return Self.hourFormatter.string(from: date)
    }
}

#Preview {
    WeekTimelineView(viewModel: CalendarViewModel())
}
