import SwiftUI

// MARK: - TimelineItem

/// Unified timeline item — either a calendar event or a timed task.
/// Used to interleave events and tasks by start time in the today timeline.
enum TimelineItem: Identifiable {
    case event(LoomEvent)
    case task(LoomTask)

    var id: String {
        switch self {
        case .event(let e): return "event-\(e._id)"
        case .task(let t): return "task-\(t._id)"
        }
    }

    var startDate: Date {
        switch self {
        case .event(let e):
            return Date(timeIntervalSince1970: TimeInterval(e.start) / 1000)
        case .task(let t):
            guard let ms = t.dueDate else { return Date.distantFuture }
            return Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        }
    }
}

// MARK: - TodayView

/// Unified event+task timeline for today.
/// Unscheduled tasks (due today with no time) appear in a collapsible section above the timeline.
/// Timed tasks appear inline at their due time alongside calendar events.
struct TodayView: View {
    @ObservedObject var calendarViewModel: CalendarViewModel
    @ObservedObject var taskViewModel: TaskViewModel

    var onEventTap: (LoomEvent) -> Void = { _ in }
    var onTaskTap: (LoomTask) -> Void = { _ in }
    var onEventDragMove: ((LoomEvent, CGFloat) -> Void)?

    // MARK: - Layout Constants

    let pointsPerHour: CGFloat = 60.0
    private let labelWidth: CGFloat = 50.0
    private var totalHeight: CGFloat { 24 * pointsPerHour }

    // MARK: - State

    @State private var scrollPosition = ScrollPosition(y: 0)
    @State private var hasScrolledToNow = false
    @State private var isTaskSectionExpanded = true
    @State private var showAllUnscheduled = false

    // MARK: - Formatters

    private static let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h a"
        return f
    }()

    // MARK: - Computed Properties

    private var today: Date { calendarViewModel.selectedDate }

    private var timedEvents: [LoomEvent] {
        calendarViewModel.timedEvents(for: today)
    }

    private var allDayEvents: [LoomEvent] {
        calendarViewModel.allDayEvents(for: today)
    }

    private var unscheduledTasks: [LoomTask] {
        // Tasks due today without a specific time, plus overdue tasks without a time
        let todayUnscheduled = taskViewModel.unscheduledTasks(dueOn: today).filter { !$0.completed }
        let overdue = taskViewModel.overdueTasks().filter { !$0.hasDueTime }
        // Merge, deduplicate by id
        var seen = Set<String>()
        return (overdue + todayUnscheduled).filter { seen.insert($0._id).inserted }
    }

    private var timedTasks: [LoomTask] {
        taskViewModel.tasksWithTime(dueOn: today).filter { !$0.completed }
    }

    /// All timeline items (events + timed tasks) sorted by start time
    private var timelineItems: [TimelineItem] {
        let eventItems = timedEvents.map { TimelineItem.event($0) }
        let taskItems = timedTasks.map { TimelineItem.task($0) }
        return (eventItems + taskItems).sorted { $0.startDate < $1.startDate }
    }

    private var visibleUnscheduledTasks: [LoomTask] {
        if showAllUnscheduled || unscheduledTasks.count <= 3 {
            return unscheduledTasks
        }
        return Array(unscheduledTasks.prefix(3))
    }

    // MARK: - Body

    var body: some View {
        // GeometryReader as ROOT — reads width before ScrollView (per project pattern)
        GeometryReader { geometry in
            let fullWidth = geometry.size.width
            let contentWidth = fullWidth - labelWidth

            VStack(spacing: 0) {
                // All-day events banner
                AllDayBannerView(events: allDayEvents)

                // Unscheduled tasks section (collapsible, above timeline)
                if !unscheduledTasks.isEmpty {
                    unscheduledTasksSection
                    Divider()
                }

                // Scrollable 24-hour timeline
                ScrollView(.vertical, showsIndicators: true) {
                    ZStack(alignment: .topLeading) {
                        // Force content height (Color.clear spacer — per project pattern)
                        Color.clear
                            .frame(width: fullWidth, height: totalHeight)

                        // Hour grid lines + labels
                        ForEach(0..<24, id: \.self) { hour in
                            hourRow(hour: hour, contentWidth: contentWidth)
                        }

                        // Now indicator
                        nowIndicator(contentWidth: contentWidth)

                        // Events (full cards)
                        eventCards(contentWidth: contentWidth)

                        // Timed task markers (compact inline rows)
                        timedTaskMarkers(contentWidth: contentWidth)
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

    // MARK: - Unscheduled Tasks Section

    @ViewBuilder
    private var unscheduledTasksSection: some View {
        VStack(spacing: 0) {
            // Header row
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isTaskSectionExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Tasks")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    // Count badge
                    Text("\(unscheduledTasks.count)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.blue))

                    Spacer()

                    Image(systemName: isTaskSectionExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if isTaskSectionExpanded {
                VStack(spacing: 0) {
                    ForEach(visibleUnscheduledTasks) { task in
                        TaskRowView(
                            task: task,
                            onComplete: {
                                Task { try? await taskViewModel.toggleComplete(task: task) }
                            },
                            onTap: { onTaskTap(task) }
                        )
                        Divider().padding(.leading, 44)
                    }

                    // "Show all" toggle if more than 3
                    if unscheduledTasks.count > 3 && !showAllUnscheduled {
                        Button {
                            withAnimation { showAllUnscheduled = true }
                        } label: {
                            Text("Show all (\(unscheduledTasks.count))")
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .background(.background)
    }

    // MARK: - Timeline Subviews

    @ViewBuilder
    private func hourRow(hour: Int, contentWidth: CGFloat) -> some View {
        let yOffset = CGFloat(hour) * pointsPerHour

        Text(hourLabel(for: hour))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(width: labelWidth, alignment: .trailing)
            .padding(.trailing, 6)
            .offset(y: yOffset - 7)

        Rectangle()
            .fill(Color.gray.opacity(0.15))
            .frame(width: contentWidth, height: 0.5)
            .offset(x: labelWidth, y: yOffset)
    }

    @ViewBuilder
    private func nowIndicator(contentWidth: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let yOffset = currentTimeYOffset(for: context.date)

            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .offset(x: labelWidth - 4, y: yOffset - 4)

            Rectangle()
                .fill(Color.red)
                .frame(width: contentWidth, height: 1.5)
                .offset(x: labelWidth, y: yOffset)
        }
    }

    @ViewBuilder
    private func eventCards(contentWidth: CGFloat) -> some View {
        let layoutEvents = computeLayout(for: timedEvents, contentWidth: contentWidth)

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

    @ViewBuilder
    private func timedTaskMarkers(contentWidth: CGFloat) -> some View {
        ForEach(timedTasks) { task in
            if let ms = task.dueDate {
                let taskDate = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
                let yPos = yOffset(for: taskDate)

                // Compact inline task marker — no card background, just inline text
                Button {
                    onTaskTap(task)
                } label: {
                    HStack(spacing: 6) {
                        // Priority dot
                        Circle()
                            .fill(task.priorityColor)
                            .frame(width: 5, height: 5)

                        // Task title
                        Text(task.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        // Completion circle
                        Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 12))
                            .foregroundStyle(task.completed ? .secondary : task.priorityColor)
                    }
                    .padding(.horizontal, 4)
                    .frame(height: 20)
                    .background(Color.clear)
                }
                .buttonStyle(.plain)
                .frame(width: contentWidth - 4)
                .offset(x: labelWidth + 2, y: yPos)
            }
        }
    }

    // MARK: - Layout Computation (matches DayTimelineView)

    private struct EventLayoutItem {
        let event: LoomEvent
        let yOffset: CGFloat
        let height: CGFloat
        let xOffset: CGFloat
        let width: CGFloat
    }

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

#Preview {
    TodayView(
        calendarViewModel: CalendarViewModel(),
        taskViewModel: TaskViewModel()
    )
}
