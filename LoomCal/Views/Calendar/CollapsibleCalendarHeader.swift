import SwiftUI

// MARK: - CollapsibleCalendarHeader

/// Fantastical-style collapsible month/week header.
/// Expanded: full month grid with event dots, month navigation arrows.
/// Collapsed: single-row week strip for the selected date's week.
/// Drag gesture on the grip handle toggles between states.
struct CollapsibleCalendarHeader: View {
    @ObservedObject var calendarViewModel: CalendarViewModel
    @ObservedObject var taskViewModel: TaskViewModel

    @State private var isExpanded: Bool = true
    @State private var dragOffset: CGFloat = 0

    /// The month being displayed (independent of selectedDate so user can browse months)
    @State private var displayedMonth: Date = .now

    private let calendar = Calendar.current
    private let collapsedHeight: CGFloat = 52
    private let expandedHeight: CGFloat = 310
    private let weekdaySymbols = Calendar.current.veryShortWeekdaySymbols

    private var targetHeight: CGFloat {
        isExpanded ? expandedHeight : collapsedHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                expandedMonthView
            } else {
                collapsedWeekStrip
            }
            gripHandle
        }
        .frame(height: max(collapsedHeight, targetHeight + dragOffset))
        .clipped()
        .onAppear {
            displayedMonth = calendarViewModel.selectedDate
        }
        .onChange(of: calendarViewModel.selectedDate) { _, newDate in
            // Keep displayed month in sync when selectedDate changes (e.g. Today button)
            if !calendar.isDate(newDate, equalTo: displayedMonth, toGranularity: .month) {
                displayedMonth = newDate
            }
        }
    }

    // MARK: - Expanded Month Grid

    private var expandedMonthView: some View {
        VStack(spacing: 4) {
            // Month/year header with navigation arrows
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(displayedMonth, format: .dateTime.month(.wide).year())
                    .font(.headline)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Weekday header row
            weekdayHeaderRow
                .padding(.horizontal, 8)

            // Day grid
            let dates = monthDates(for: displayedMonth)
            let rows = dates.chunked(into: 7)
            VStack(spacing: 2) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, week in
                    let isCurrentWeek = week.contains { date in
                        guard let date else { return false }
                        return calendar.isDate(date, equalTo: calendarViewModel.selectedDate, toGranularity: .weekOfYear)
                    }
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { i in
                            if i < week.count, let date = week[i] {
                                dayCell(date: date, dimmed: !calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month))
                            } else {
                                Color.clear.frame(maxWidth: .infinity, minHeight: 38)
                            }
                        }
                    }
                    .background(
                        isCurrentWeek
                            ? RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.06))
                            : nil
                    )
                }
            }
            .padding(.horizontal, 8)
        }
    }

    // MARK: - Collapsed Week Strip

    private var collapsedWeekStrip: some View {
        let weekDates = currentWeekDates(around: calendarViewModel.selectedDate)
        return HStack(spacing: 0) {
            ForEach(weekDates, id: \.self) { date in
                weekStripCell(date: date)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    // MARK: - Grip Handle

    private var gripHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 20)
            .overlay {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 36, height: 5)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 40
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if isExpanded && value.translation.height < -threshold {
                                isExpanded = false
                            } else if !isExpanded && value.translation.height > threshold {
                                isExpanded = true
                            }
                            dragOffset = 0
                        }
                    }
            )
    }

    // MARK: - Day Cell (expanded grid)

    private func dayCell(date: Date, dimmed: Bool) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: calendarViewModel.selectedDate)
        let isToday = calendar.isDateInToday(date)
        let hasEvents = !calendarViewModel.events(for: date).isEmpty
        let hasTasks = !taskViewModel.tasks(dueOn: date).isEmpty

        return Button {
            calendarViewModel.selectedDate = date
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: isSelected || isToday ? .bold : .regular))
                    .foregroundStyle(
                        isSelected ? .white : isToday ? LoomColors.todayAccent : dimmed ? .secondary : .primary
                    )
                    .frame(width: 30, height: 30)
                    .background {
                        if isSelected {
                            Circle().fill(LoomColors.selectedDateFill)
                        } else if isToday {
                            Circle().stroke(LoomColors.todayAccent, lineWidth: 1.5)
                        }
                    }

                // Event/task indicator dots
                HStack(spacing: 2) {
                    if hasEvents {
                        Circle()
                            .fill(isSelected ? Color.white.opacity(0.8) : LoomColors.eventDot)
                            .frame(width: 4, height: 4)
                    }
                    if hasTasks {
                        Circle()
                            .fill(isSelected ? Color.white.opacity(0.8) : LoomColors.taskDot)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 38)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Week Strip Cell (collapsed)

    private func weekStripCell(date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: calendarViewModel.selectedDate)
        let isToday = calendar.isDateInToday(date)
        let hasEvents = !calendarViewModel.events(for: date).isEmpty
        let hasTasks = !taskViewModel.tasks(dueOn: date).isEmpty

        return Button {
            calendarViewModel.selectedDate = date
        } label: {
            VStack(spacing: 2) {
                Text(weekdaySymbols[calendar.component(.weekday, from: date) - 1])
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: isSelected || isToday ? .bold : .regular))
                    .foregroundStyle(isSelected ? .white : isToday ? LoomColors.todayAccent : .primary)
                    .frame(width: 30, height: 30)
                    .background {
                        if isSelected {
                            Circle().fill(LoomColors.selectedDateFill)
                        } else if isToday {
                            Circle().stroke(LoomColors.todayAccent, lineWidth: 1.5)
                        }
                    }

                HStack(spacing: 2) {
                    if hasEvents {
                        Circle()
                            .fill(isSelected ? Color.white.opacity(0.8) : LoomColors.eventDot)
                            .frame(width: 4, height: 4)
                    }
                    if hasTasks {
                        Circle()
                            .fill(isSelected ? Color.white.opacity(0.8) : LoomColors.taskDot)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weekday Header Row

    private var weekdayHeaderRow: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Date Math

    /// All dates to display in the month grid, including leading/trailing days from adjacent months.
    private func monthDates(for referenceDate: Date) -> [Date?] {
        let components = calendar.dateComponents([.year, .month], from: referenceDate)
        guard let monthStart = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingEmpty = (firstWeekday - calendar.firstWeekday + 7) % 7

        // Leading days from previous month
        var dates: [Date?] = []
        if leadingEmpty > 0 {
            for i in stride(from: leadingEmpty, through: 1, by: -1) {
                dates.append(calendar.date(byAdding: .day, value: -i, to: monthStart))
            }
        }

        // Current month days
        for day in range {
            var dayComponents = components
            dayComponents.day = day
            dates.append(calendar.date(from: dayComponents))
        }

        // Trailing days to fill last row
        let remainder = dates.count % 7
        if remainder > 0 {
            let lastDay = dates.last ?? monthStart
            for i in 1...(7 - remainder) {
                dates.append(calendar.date(byAdding: .day, value: i, to: lastDay!))
            }
        }

        return dates
    }

    /// The 7 dates of the week containing the given date.
    private func currentWeekDates(around date: Date) -> [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekInterval.start) }
    }
}

// MARK: - Array Chunking Helper

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
