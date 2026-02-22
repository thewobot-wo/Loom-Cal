import SwiftUI

/// Full month grid view for the main content area.
/// Shows 7-column grid with event summaries per cell (up to 4 + "+N more").
/// Tap selects date; double-tap switches to day view.
struct MonthGridView: View {
    @ObservedObject var calendarViewModel: CalendarViewModel
    @ObservedObject var taskViewModel: TaskViewModel

    private let calendar = Calendar.current
    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

    private var displayedMonth: Date { calendarViewModel.selectedDate }

    private var monthDates: [Date?] {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let monthStart = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingEmpty = (firstWeekday - calendar.firstWeekday + 7) % 7

        var dates: [Date?] = Array(repeating: nil, count: leadingEmpty)
        for day in range {
            var dayComponents = components
            dayComponents.day = day
            dates.append(calendar.date(from: dayComponents))
        }
        // Pad to fill last row
        let remainder = dates.count % 7
        if remainder > 0 {
            dates += Array(repeating: nil as Date?, count: 7 - remainder)
        }
        return dates
    }

    private var weekRows: [[Date?]] {
        stride(from: 0, to: monthDates.count, by: 7).map {
            Array(monthDates[$0..<min($0 + 7, monthDates.count)])
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let rowCount = max(weekRows.count, 1)
            let headerHeight: CGFloat = 30
            let rowHeight = (geometry.size.height - headerHeight) / CGFloat(rowCount)

            VStack(spacing: 0) {
                // Weekday header
                HStack(spacing: 0) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: headerHeight)

                Divider()

                // Week rows
                ForEach(Array(weekRows.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { i in
                            if i < week.count, let date = week[i] {
                                monthDayCell(date: date, height: rowHeight)
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity)
                                    .frame(height: rowHeight)
                            }
                        }
                    }
                    Divider()
                }
            }
        }
    }

    // MARK: - Day Cell

    @ViewBuilder
    private func monthDayCell(date: Date, height: CGFloat) -> some View {
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: calendarViewModel.selectedDate)
        let dayEvents = calendarViewModel.events(for: date)
        let maxVisible = 4

        VStack(alignment: .leading, spacing: 2) {
            // Day number
            HStack {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 12, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isSelected ? .white : isToday ? LoomColors.todayAccent : .primary)
                    .frame(width: 22, height: 22)
                    .background {
                        if isSelected {
                            Circle().fill(LoomColors.selectedDateFill)
                        }
                    }
                Spacer()
            }
            .padding(.leading, 4)
            .padding(.top, 2)

            // Event summaries
            ForEach(Array(dayEvents.prefix(maxVisible).enumerated()), id: \.offset) { _, event in
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(eventCellColor(for: event))
                        .frame(width: 3, height: 12)
                    Text(event.title)
                        .font(.system(size: 9))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 3)
            }

            if dayEvents.count > maxVisible {
                Text("+\(dayEvents.count - maxVisible) more")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 6)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(isToday ? LoomColors.coral.opacity(0.06) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            calendarViewModel.selectedDate = date
        }
        .onTapGesture(count: 2) {
            calendarViewModel.selectedDate = date
            calendarViewModel.viewMode = .day
        }
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(width: 0.5)
                .frame(maxHeight: .infinity),
            alignment: .trailing
        )
    }

    private func eventCellColor(for event: LoomEvent) -> Color {
        if let hex = event.color {
            return Color(hex: hex)
        }
        return event.taskId != nil ? LoomColors.timeBlockAccent : LoomColors.eventAccent
    }
}

// MARK: - Color from Hex (shared utility)

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b: Double
        switch cleaned.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}
