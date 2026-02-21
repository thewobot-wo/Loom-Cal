import SwiftUI

/// 7-column week timeline view.
/// The day header row IS the navigation — tapping a day selects it.
/// Mini month is hidden in week mode to maximize timeline space.
struct WeekTimelineView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @ObservedObject var taskViewModel: TaskViewModel
    var onEventTap: (LoomEvent) -> Void = { _ in }

    // MARK: - Layout Constants

    let pointsPerHour: CGFloat = 50.0
    private let gutterWidth: CGFloat = 38.0
    private var totalHeight: CGFloat { 24 * pointsPerHour }

    @State private var scrollPosition = ScrollPosition(y: 0)
    @State private var hasScrolledToNow = false

    // MARK: - Formatters

    private static let dayNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    private static let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "ha"
        return f
    }()

    // MARK: - Week Dates

    private var weekDates: [Date] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: viewModel.selectedDate) else {
            return []
        }
        return (0..<7).compactMap { day in
            calendar.date(byAdding: .day, value: day, to: weekInterval.start)
        }
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let columnWidth = (geometry.size.width - gutterWidth) / 7

            VStack(spacing: 0) {
                // Week navigation header
                weekHeader(columnWidth: columnWidth)

                Divider()

                // Scrollable week timeline
                ScrollView(.vertical, showsIndicators: true) {
                    ZStack(alignment: .topLeading) {
                        // Force content height
                        Color.clear
                            .frame(width: geometry.size.width, height: totalHeight)

                        // Hour grid lines
                        ForEach(0..<24, id: \.self) { hour in
                            hourGridLine(hour: hour, totalWidth: geometry.size.width)
                            if hour % 2 == 0 {
                                hourLabel(hour: hour)
                            }
                        }

                        // Now indicator
                        nowIndicator(totalWidth: geometry.size.width)

                        // Day columns with events
                        HStack(spacing: 0) {
                            Color.clear.frame(width: gutterWidth)

                            ForEach(weekDates, id: \.self) { date in
                                dayColumn(for: date, width: columnWidth)
                            }
                        }
                    }
                }
                .scrollPosition($scrollPosition)
                .onAppear {
                    guard !hasScrolledToNow else { return }
                    hasScrolledToNow = true
                    let yOffset = max(0, currentTimeYOffset() - 100)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        scrollPosition = ScrollPosition(y: yOffset)
                    }
                }
            }
        }
    }

    // MARK: - Week Header

    @ViewBuilder
    private func weekHeader(columnWidth: CGFloat) -> some View {
        let calendar = Calendar.current

        // Month/year label + day cells
        VStack(spacing: 6) {
            // Month label derived from the current week
            if let firstDate = weekDates.first {
                Text(firstDate.formatted(.dateTime.month(.wide).year()))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            // Day cells row
            HStack(spacing: 0) {
                Color.clear.frame(width: gutterWidth)

                ForEach(weekDates, id: \.self) { date in
                    let isToday = calendar.isDateInToday(date)
                    let isSelected = calendar.isDate(date, inSameDayAs: viewModel.selectedDate)
                    let dayNum = calendar.component(.day, from: date)

                    let dayTasks = taskViewModel.tasks(dueOn: date).filter { !$0.completed }

                    VStack(spacing: 3) {
                        Text(Self.dayNameFormatter.string(from: date).uppercased())
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isToday ? .blue : .secondary)

                        Text("\(dayNum)")
                            .font(.system(size: 16, weight: isToday || isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? .white : isToday ? .blue : .primary)
                            .frame(width: 30, height: 30)
                            .background {
                                if isSelected {
                                    Circle().fill(.blue)
                                } else if isToday {
                                    Circle().strokeBorder(.blue, lineWidth: 1.5)
                                }
                            }

                        // Task dots — up to 3, colored by priority (max 3 per CONTEXT.md)
                        if !dayTasks.isEmpty {
                            HStack(spacing: 2) {
                                ForEach(Array(dayTasks.prefix(3))) { task in
                                    Circle()
                                        .fill(task.priorityColor)
                                        .frame(width: 5, height: 5)
                                }
                            }
                        } else {
                            // Fixed-height spacer to maintain consistent header height
                            Color.clear.frame(height: 5)
                        }
                    }
                    .frame(width: columnWidth)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectedDate = date
                    }
                }
            }
            .padding(.bottom, 6)
        }
        .background(.background)
    }

    // MARK: - Hour Grid

    @ViewBuilder
    private func hourGridLine(hour: Int, totalWidth: CGFloat) -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.12))
            .frame(width: totalWidth - gutterWidth, height: 0.5)
            .offset(x: gutterWidth, y: CGFloat(hour) * pointsPerHour)
    }

    @ViewBuilder
    private func hourLabel(hour: Int) -> some View {
        Text(hourLabelText(for: hour))
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .frame(width: gutterWidth - 4, alignment: .trailing)
            .offset(y: CGFloat(hour) * pointsPerHour - 6)
    }

    // MARK: - Now Indicator

    @ViewBuilder
    private func nowIndicator(totalWidth: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let yPos = currentTimeYOffset(for: context.date)

            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)
                .offset(x: gutterWidth - 3, y: yPos - 3)

            Rectangle()
                .fill(Color.red)
                .frame(width: totalWidth - gutterWidth, height: 1)
                .offset(x: gutterWidth, y: yPos)
        }
    }

    // MARK: - Day Column

    @ViewBuilder
    private func dayColumn(for date: Date, width: CGFloat) -> some View {
        let events = viewModel.timedEvents(for: date)

        ZStack(alignment: .topLeading) {
            // Column separator
            Rectangle()
                .fill(Color.gray.opacity(0.08))
                .frame(width: 0.5)
                .frame(height: totalHeight)

            // Events
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
        let eventHeight = max(CGFloat(event.duration) / 60.0 * pointsPerHour, 16)

        Button(action: { onEventTap(event) }) {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.blue)
                    .frame(width: 2.5)

                if columnWidth > 50 {
                    Text(event.title)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.blue.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .frame(width: columnWidth - 3, height: eventHeight)
        .offset(x: 1.5, y: yPos)
    }

    // MARK: - Helpers

    private func currentTimeYOffset(for date: Date = Date()) -> CGFloat {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return CGFloat(hour * 60 + minute) / 60.0 * pointsPerHour
    }

    private func yOffsetForStart(_ startMs: Int) -> CGFloat {
        let date = Date(timeIntervalSince1970: TimeInterval(startMs) / 1000)
        return currentTimeYOffset(for: date)
    }

    private func hourLabelText(for hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        let date = Calendar.current.date(from: components) ?? Date()
        return Self.hourFormatter.string(from: date).lowercased()
    }
}

#Preview {
    WeekTimelineView(viewModel: CalendarViewModel(), taskViewModel: TaskViewModel())
}
