import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - TaskDragState

/// Carries the dragging task and its current global coordinate.
/// `ended` is set to true on gesture release to trigger drop resolution.
struct TaskDragState {
    let task: LoomTask
    let location: CGPoint   // global coordinate
    var ended: Bool = false
}

// MARK: - TimelineFrameKey

/// PreferenceKey that captures the timeline ZStack's frame in global coordinates.
/// Used by drop-resolution logic to convert drag position to a time slot.
struct TimelineFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - TimelineContentOriginKey

/// Tracks the global Y of the timeline content origin (Color.clear spacer).
/// The difference between this and timelineGlobalFrame.minY is the scroll offset.
struct TimelineContentOriginKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

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

// MARK: - DraggableTaskRow

/// Wraps TaskRowView with LongPress + DragGesture for drag-to-time-block.
/// Pattern mirrors TimelineEventCard.swift (Phase 2) exactly.
/// The drag source is in the fixed panel ABOVE the ScrollView — critical for
/// avoiding scroll gesture conflicts (RESEARCH.md Pitfall 1).
private struct DraggableTaskRow: View {
    let task: LoomTask
    @Binding var dragState: TaskDragState?
    var onComplete: () -> Void = {}
    var onTap: () -> Void = {}
    var isHighlighted: Bool = false

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false

    var body: some View {
        TaskRowView(
            task: task,
            onComplete: onComplete,
            onTap: onTap,
            isHighlighted: isHighlighted
        )
        .offset(dragOffset)
        .opacity(isDragging ? 0.7 : 1.0)
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .animation(.interactiveSpring(), value: isDragging)
        .gesture(
            LongPressGesture(minimumDuration: 0.2)
                .sequenced(before: DragGesture(minimumDistance: 4, coordinateSpace: .global))
                .onChanged { value in
                    switch value {
                    case .first:
                        isDragging = true
                    case .second(true, let drag?):
                        isDragging = true
                        dragOffset = drag.translation
                        dragState = TaskDragState(task: task, location: drag.location)
                    default:
                        break
                    }
                }
                .onEnded { value in
                    if case .second(true, let drag?) = value {
                        dragState = TaskDragState(task: task, location: drag.location, ended: true)
                    } else {
                        dragState = nil
                    }
                    withAnimation(.easeOut(duration: 0.15)) {
                        dragOffset = .zero
                        isDragging = false
                    }
                }
        )
    }
}

// MARK: - TodayView

/// Unified event+task timeline for today.
/// Unscheduled tasks (due today with no time) appear in a collapsible section above the timeline.
/// Timed tasks appear inline at their due time alongside calendar events.
/// Supports drag-to-time-block: long-press an unscheduled task and drag onto timeline.
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

    // Drag-to-time-block state
    @State private var dragState: TaskDragState?
    @State private var timelineGlobalFrame: CGRect = .zero
    /// Global Y of the timeline content origin — used to compute scroll offset.
    /// scrollOffset = timelineContentOriginY - timelineGlobalFrame.minY
    @State private var timelineContentOriginY: CGFloat = 0

    // Undo state — shown after task completion
    @State private var undoTask: LoomTask?

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

    // MARK: - Drag drop indicator Y position (within timeline)

    /// Current scroll offset derived from content origin vs frame origin.
    private var currentScrollOffset: CGFloat {
        timelineContentOriginY - timelineGlobalFrame.minY
    }

    /// Returns the Y offset within the timeline ZStack for the current drag location,
    /// accounting for scroll offset. Returns nil when outside the timeline.
    private var dragIndicatorY: CGFloat? {
        guard let drag = dragState, !drag.ended,
              timelineGlobalFrame != .zero else { return nil }
        let localY = drag.location.y - timelineGlobalFrame.minY - currentScrollOffset
        guard localY >= 0 && localY <= totalHeight else { return nil }
        // Snap to 15-minute grid (same as resolveTimeSlot)
        let minutesFromMidnight = (localY / pointsPerHour) * 60
        let rounded = (minutesFromMidnight / 15).rounded() * 15
        return rounded / 60.0 * pointsPerHour
    }

    // MARK: - Body

    var body: some View {
        // GeometryReader as ROOT — reads width before ScrollView (per project pattern)
        GeometryReader { geometry in
            let fullWidth = geometry.size.width
            let contentWidth = fullWidth - labelWidth

            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // All-day events banner
                    AllDayBannerView(events: allDayEvents)

                    // Unscheduled tasks section (collapsible, above timeline — critical: NOT inside ScrollView)
                    if !unscheduledTasks.isEmpty {
                        unscheduledTasksSection(contentWidth: fullWidth)
                        Divider()
                    }

                    // Scrollable 24-hour timeline
                    ScrollView(.vertical, showsIndicators: true) {
                        ZStack(alignment: .topLeading) {
                            // Force content height (Color.clear spacer — per project pattern).
                            // Also tracks global Y to compute scroll offset for drag resolution.
                            Color.clear
                                .frame(width: fullWidth, height: totalHeight)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear
                                            .preference(
                                                key: TimelineContentOriginKey.self,
                                                value: geo.frame(in: .global).minY
                                            )
                                    }
                                )

                            // Hour grid lines + labels
                            ForEach(0..<24, id: \.self) { hour in
                                hourRow(hour: hour, contentWidth: contentWidth)
                            }

                            // Now indicator
                            nowIndicator(contentWidth: contentWidth)

                            // Events (full cards — time-blocked events rendered with orange style)
                            eventCards(contentWidth: contentWidth)

                            // Timed task markers (compact inline rows)
                            timedTaskMarkers(contentWidth: contentWidth)

                            // Drag preview indicator line — shows target time slot during drag
                            if let indicatorY = dragIndicatorY {
                                Rectangle()
                                    .fill(Color.orange.opacity(0.5))
                                    .frame(width: contentWidth, height: 2)
                                    .offset(x: labelWidth, y: indicatorY)
                                    .allowsHitTesting(false)
                            }
                        }
                        // Capture timeline ZStack global frame for drop resolution
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(
                                        key: TimelineFrameKey.self,
                                        value: geo.frame(in: .global)
                                    )
                            }
                        )
                        .onPreferenceChange(TimelineFrameKey.self) { frame in
                            timelineGlobalFrame = frame
                        }
                        .onPreferenceChange(TimelineContentOriginKey.self) { originY in
                            timelineContentOriginY = originY
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
                    // Resolve drop when drag ends over the timeline
                    .onChange(of: dragState?.ended) { _, ended in
                        guard ended == true, let drag = dragState else { return }
                        handleDrop(drag: drag)
                    }
                }

                // Undo banner — floats above content, appears after task completion
                if let task = undoTask {
                    undoBanner(for: task)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: undoTask != nil)
        }
    }

    // MARK: - Drop Resolution

    private func handleDrop(drag: TaskDragState) {
        defer { dragState = nil }
        let scrollOffset = currentScrollOffset
        guard let resolvedDate = resolveTimeSlot(globalPoint: drag.location,
                                                  timelineFrame: timelineGlobalFrame,
                                                  scrollOffset: scrollOffset) else {
            return  // dropped outside timeline — no action
        }
        // Haptic feedback on successful drop
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif

        Task {
            try? await taskViewModel.createTimeBlock(for: drag.task, at: resolvedDate)
        }
    }

    /// Converts a global drag location to a snapped time slot Date.
    /// Returns nil when the drop point is outside the timeline frame.
    /// localY = global_drag_y - timeline_visible_top - scrollOffset
    /// where scrollOffset = contentOriginY - frameMinY (negative when scrolled down)
    private func resolveTimeSlot(
        globalPoint: CGPoint,
        timelineFrame: CGRect,
        scrollOffset: CGFloat
    ) -> Date? {
        // Subtract scrollOffset (which is negative when scrolled down) to get content position
        let localY = globalPoint.y - timelineFrame.minY - scrollOffset
        guard localY >= 0 && localY <= totalHeight else { return nil }
        let minutesFromMidnight = (localY / pointsPerHour) * 60
        // Round to nearest 15 minutes
        let rounded = (minutesFromMidnight / 15).rounded() * 15
        let dayStart = Calendar.current.startOfDay(for: calendarViewModel.selectedDate)
        return dayStart.addingTimeInterval(rounded * 60)
    }

    // MARK: - Unscheduled Tasks Section

    @ViewBuilder
    private func unscheduledTasksSection(contentWidth: CGFloat) -> some View {
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
                        DraggableTaskRow(
                            task: task,
                            dragState: $dragState,
                            onComplete: {
                                handleTaskComplete(task)
                            },
                            onTap: { onTaskTap(task) },
                            isHighlighted: taskViewModel.highlightedTaskId == task._id
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

    // MARK: - Task Completion + Undo

    private func handleTaskComplete(_ task: LoomTask) {
        Task { try? await taskViewModel.toggleComplete(task: task) }
        withAnimation {
            undoTask = task
        }
        // Auto-dismiss undo banner after 3 seconds
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation {
                if undoTask?._id == task._id {
                    undoTask = nil
                }
            }
        }
    }

    @ViewBuilder
    private func undoBanner(for task: LoomTask) -> some View {
        HStack {
            Text("Task completed")
                .font(.subheadline)
            Spacer()
            Button("Undo") {
                Task { try? await taskViewModel.toggleComplete(task: task) }
                withAnimation { undoTask = nil }
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                isTimeBlock: item.event.taskId != nil,
                isHighlighted: calendarViewModel.highlightedEventId == item.event._id,
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
