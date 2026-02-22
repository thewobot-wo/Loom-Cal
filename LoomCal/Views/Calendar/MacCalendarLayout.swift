#if os(macOS)
import SwiftUI

/// Fantastical-style 3-zone layout for macOS: fixed sidebar + toolbar + main content.
struct MacCalendarLayout: View {
    @ObservedObject var calendarViewModel: CalendarViewModel
    @ObservedObject var taskViewModel: TaskViewModel

    var onEventTap: (LoomEvent) -> Void = { _ in }
    var onTaskTap: (LoomTask) -> Void = { _ in }

    private let sidebarWidth: CGFloat = 280

    var body: some View {
        HStack(spacing: 0) {
            // MARK: Left Sidebar
            sidebar

            Divider()

            // MARK: Main Area (toolbar + content)
            VStack(spacing: 0) {
                CalendarToolbar(viewModel: calendarViewModel)
                Divider()
                mainContent
            }
        }
        .background(LoomColors.contentBackground)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            MacMiniMonthView(
                viewModel: calendarViewModel,
                taskViewModel: taskViewModel
            )

            Divider()

            DayEventListView(
                calendarViewModel: calendarViewModel,
                taskViewModel: taskViewModel,
                onEventTap: onEventTap,
                onTaskTap: onTaskTap
            )
        }
        .frame(width: sidebarWidth)
        .background(LoomColors.sidebarBackground)
    }

    // MARK: - Main Content (switches on viewMode)

    @ViewBuilder
    private var mainContent: some View {
        switch calendarViewModel.viewMode {
        case .day:
            TodayView(
                calendarViewModel: calendarViewModel,
                taskViewModel: taskViewModel,
                onEventTap: onEventTap,
                onTaskTap: onTaskTap
            )
        case .week:
            WeekTimelineView(
                viewModel: calendarViewModel,
                taskViewModel: taskViewModel,
                onEventTap: onEventTap
            )
        case .month:
            MonthGridView(
                calendarViewModel: calendarViewModel,
                taskViewModel: taskViewModel
            )
        }
    }
}
#endif
