import SwiftUI

// MARK: - DayEventListView

/// Fantastical-style scrolling event list replacing the 24-hour timeline.
/// Shows the selected day + subsequent days with events and tasks mixed together.
/// Day sections include all-day event pills, timed events, timed tasks, and unscheduled tasks.
struct DayEventListView: View {
    @ObservedObject var calendarViewModel: CalendarViewModel
    @ObservedObject var taskViewModel: TaskViewModel

    var onEventTap: (LoomEvent) -> Void
    var onTaskTap: (LoomTask) -> Void

    /// Number of days to show ahead of the selected date
    private let lookAheadDays = 7

    private var visibleDays: [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: calendarViewModel.selectedDate)
        return (0..<lookAheadDays).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(visibleDays, id: \.self) { day in
                    let allDay = calendarViewModel.allDayEvents(for: day)
                    let timed = calendarViewModel.timedEvents(for: day)
                        .sorted { $0.start < $1.start }
                    let timedTasks = taskViewModel.tasksWithTime(dueOn: day)
                        .sorted { ($0.dueDate ?? 0) < ($1.dueDate ?? 0) }
                    let unscheduled = taskViewModel.unscheduledTasks(dueOn: day)
                        .filter { !$0.completed }

                    let hasContent = !allDay.isEmpty || !timed.isEmpty || !timedTasks.isEmpty || !unscheduled.isEmpty

                    if hasContent {
                        Section {
                            daySectionContent(
                                day: day,
                                allDayEvents: allDay,
                                timedEvents: timed,
                                timedTasks: timedTasks,
                                unscheduledTasks: unscheduled
                            )
                        } header: {
                            daySectionHeader(day: day)
                        }
                    }
                }

                // Empty state when no days have content
                if visibleDays.allSatisfy({ day in
                    calendarViewModel.events(for: day).isEmpty && taskViewModel.tasks(dueOn: day).isEmpty
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 40))
                            .foregroundStyle(.quaternary)
                        Text("No events or tasks")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }
            }
        }
    }

    // MARK: - Day Section Header

    private func daySectionHeader(day: Date) -> some View {
        let calendar = Calendar.current
        let label: String = {
            if calendar.isDateInToday(day) { return "TODAY" }
            if calendar.isDateInTomorrow(day) { return "TOMORROW" }
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: day).uppercased()
        }()

        return HStack(spacing: 6) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(calendar.isDateInToday(day) ? LoomColors.todayAccent : .secondary)
            Text(day, format: .dateTime.month(.abbreviated).day())
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    // MARK: - Day Section Content

    private func daySectionContent(
        day: Date,
        allDayEvents: [LoomEvent],
        timedEvents: [LoomEvent],
        timedTasks: [LoomTask],
        unscheduledTasks: [LoomTask]
    ) -> some View {
        let mergedItems = mergeTimedItems(events: timedEvents, tasks: timedTasks)
        return VStack(spacing: 0) {
            // All-day events as colored pills
            if !allDayEvents.isEmpty {
                allDayPills(events: allDayEvents)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
            }

            // Merged timed events and tasks, sorted by time
            ForEach(mergedItems) { item in
                switch item {
                case .event(let event):
                    eventRow(event: event)
                        .highlightPulse(active: calendarViewModel.highlightedEventId == event._id)
                case .task(let task):
                    taskRow(task: task)
                        .highlightPulse(active: taskViewModel.highlightedTaskId == task._id)
                }
            }

            // Unscheduled tasks
            if !unscheduledTasks.isEmpty {
                HStack(spacing: 4) {
                    Text("To Do")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 2)

                ForEach(unscheduledTasks) { task in
                    taskRow(task: task)
                        .highlightPulse(active: taskViewModel.highlightedTaskId == task._id)
                }
            }

            Divider()
                .padding(.top, 8)
        }
    }

    // MARK: - All-Day Pills

    private func allDayPills(events: [LoomEvent]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(events) { event in
                    Button {
                        onEventTap(event)
                    } label: {
                        Text(event.title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(eventColor(for: event))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Event Row

    private func eventRow(event: LoomEvent) -> some View {
        Button {
            onEventTap(event)
        } label: {
            HStack(spacing: 10) {
                // Calendar color dot
                Circle()
                    .fill(eventColor(for: event))
                    .frame(width: 8, height: 8)

                // Time range
                VStack(alignment: .leading, spacing: 0) {
                    Text(eventTimeRange(event))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 80, alignment: .leading)

                // Title + location
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let location = event.location, !location.isEmpty {
                        Text(location)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Task Row

    private func taskRow(task: LoomTask) -> some View {
        Button {
            onTaskTap(task)
        } label: {
            HStack(spacing: 10) {
                // Completion checkbox
                Button {
                    Task { try? await taskViewModel.toggleComplete(task: task) }
                } label: {
                    Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(task.completed ? .secondary : task.priorityColor)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)

                // Due time (if task has a specific time)
                if task.hasDueTime, let date = task.dueDateAsDate {
                    Text(date, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                }

                // Title
                Text(task.title)
                    .font(.subheadline)
                    .strikethrough(task.completed)
                    .foregroundStyle(task.completed ? .secondary : .primary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func eventColor(for event: LoomEvent) -> Color {
        if let hex = event.color {
            return Color(hex: hex)
        }
        return event.taskId != nil ? LoomColors.timeBlockAccent : LoomColors.eventAccent
    }

    private func eventTimeRange(_ event: LoomEvent) -> String {
        let startDate = Date(timeIntervalSince1970: TimeInterval(event.start) / 1000)
        let endDate = startDate.addingTimeInterval(TimeInterval(event.duration) * 60)

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let startStr = formatter.string(from: startDate)

        // If end is same period (AM/PM), omit it from start
        let endStr = formatter.string(from: endDate)
        let startPeriod = String(startStr.suffix(2))
        let endPeriod = String(endStr.suffix(2))

        if startPeriod == endPeriod {
            let startNoAmPm = String(startStr.dropLast(3))
            return "\(startNoAmPm) - \(endStr)"
        }
        return "\(startStr) - \(endStr)"
    }
}

// MARK: - Merged Timeline Item

/// Represents either an event or a task in the merged timed list.
private enum DayListItem: Identifiable {
    case event(LoomEvent)
    case task(LoomTask)

    var id: String {
        switch self {
        case .event(let e): return "event-\(e._id)"
        case .task(let t): return "task-\(t._id)"
        }
    }

    var sortTimestamp: Int {
        switch self {
        case .event(let e): return e.start
        case .task(let t): return t.dueDate ?? 0
        }
    }
}

private func mergeTimedItems(events: [LoomEvent], tasks: [LoomTask]) -> [DayListItem] {
    let eventItems = events.map { DayListItem.event($0) }
    let taskItems = tasks.map { DayListItem.task($0) }
    return (eventItems + taskItems).sorted { $0.sortTimestamp < $1.sortTimestamp }
}

// Color(hex:) extension is defined in MonthGridView.swift
