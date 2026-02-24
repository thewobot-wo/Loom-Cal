import SwiftUI
import ConvexMobile

// MARK: - CalendarViewMode

/// View mode for the main calendar content area (macOS toolbar picker).
enum CalendarViewMode: String, CaseIterable, Identifiable {
    case day, week, month
    var id: String { rawValue }

    var label: String {
        switch self {
        case .day:   return "Day"
        case .week:  return "Week"
        case .month: return "Month"
        }
    }
}

// CalendarViewModel is the single source of truth for all calendar state.
// It owns the Convex subscription, the selected date, and all CRUD mutations.
// All calendar views observe this via @ObservedObject or @StateObject.
// Anti-pattern avoided: subscription lives here, not in a view's .task{} block.
@MainActor
class CalendarViewModel: ObservableObject {
    // MARK: - Published State

    /// All events from the Convex events:list subscription
    @Published var events: [LoomEvent] = []

    /// Currently selected/viewed date — drives DayTimelineView and MiniMonthView
    @Published var selectedDate: Date = .now

    /// Current view mode — Day/Week/Month (used by macOS toolbar picker)
    @Published var viewMode: CalendarViewMode = .week

    /// True while waiting for first subscription result
    @Published var isLoading: Bool = true

    /// ID of the event to highlight after a Loom action mutation — drives flash animation in views.
    /// Automatically cleared after 2 seconds by flashHighlight(eventId:).
    @Published var highlightedEventId: String? = nil

    // MARK: - Private

    /// Task handle for the subscription loop — cancel before re-subscribing
    private var subscriptionTask: Task<Void, Never>?

    // MARK: - Subscription

    /// Starts the Convex events:list subscription. Cancel previous before re-subscribing.
    /// Pattern: for-await over replaceError(with: []).values — never crashes on errors.
    func startSubscription() {
        subscriptionTask?.cancel()
        subscriptionTask = Task {
            for await result: [LoomEvent] in convex
                .subscribe(to: "events:list")
                .replaceError(with: [])
                .values
            {
                // Task could be cancelled between iterations
                guard !Task.isCancelled else { break }
                self.events = result
                self.isLoading = false
                NotificationService.shared.rescheduleEventNotifications(result)
            }
        }
    }

    /// Cancels the active subscription task.
    func stopSubscription() {
        subscriptionTask?.cancel()
        subscriptionTask = nil
    }

    // MARK: - Date Filtering

    /// All events (timed and all-day) whose start falls within the given calendar day.
    /// Expands recurring events into virtual occurrences for the requested date.
    func events(for date: Date) -> [LoomEvent] {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!

        var result: [LoomEvent] = []

        for event in events {
            if event.isRecurring {
                // Expand recurring event — check if any occurrence falls on this day
                result.append(contentsOf: expandRecurringEvent(event, dayStart: dayStart, dayEnd: dayEnd))
            } else {
                // Non-recurring: original date filter
                let ms = TimeInterval(event.start) / 1000
                let d = Date(timeIntervalSince1970: ms)
                if d >= dayStart && d < dayEnd {
                    result.append(event)
                }
            }
        }

        return result
    }

    /// All-day events for the given date.
    func allDayEvents(for date: Date) -> [LoomEvent] {
        events(for: date).filter { $0.isAllDay }
    }

    /// Timed (non-all-day) events for the given date.
    func timedEvents(for date: Date) -> [LoomEvent] {
        events(for: date).filter { !$0.isAllDay }
    }

    // MARK: - Recurrence Expansion

    /// Expand a recurring master event into virtual occurrences that fall within [dayStart, dayEnd).
    /// Returns the master itself if its original start falls in range, plus any virtual occurrences.
    private func expandRecurringEvent(_ master: LoomEvent, dayStart: Date, dayEnd: Date) -> [LoomEvent] {
        guard let rruleStr = master.rrule, let rule = RecurrenceRule.from(rrule: rruleStr) else {
            // Invalid/unparseable rrule — fall back to treating as non-recurring
            let ms = TimeInterval(master.start) / 1000
            let d = Date(timeIntervalSince1970: ms)
            return (d >= dayStart && d < dayEnd) ? [master] : []
        }

        let masterStart = Date(timeIntervalSince1970: TimeInterval(master.start) / 1000)
        let exceptions = master.exceptionDateValues

        // Expand from master start through end of requested day
        // Use a 1-year horizon cap to avoid unbounded expansion
        let cal = Calendar.current
        let horizon = cal.date(byAdding: .year, value: 1, to: masterStart) ?? dayEnd
        let expansionEnd = min(dayEnd, horizon)

        // Only expand if the requested day is on or after the master start
        guard dayEnd > masterStart else { return [] }

        let occurrenceDates = rule.occurrences(from: masterStart, through: expansionEnd, excluding: exceptions)

        var results: [LoomEvent] = []
        for occDate in occurrenceDates {
            let occDayStart = cal.startOfDay(for: occDate)
            guard occDayStart == dayStart else { continue }

            let occMs = Int(occDate.timeIntervalSince1970 * 1000)
            if occMs == master.start {
                // Original occurrence — use the master event directly
                results.append(master)
            } else {
                // Virtual occurrence — create with synthetic ID
                results.append(LoomEvent.virtualOccurrence(of: master, startMs: occMs))
            }
        }

        return results
    }

    // MARK: - CRUD Mutations

    /// Creates a new event in Convex.
    /// - Parameter start: Event start time (converted to ms Int — SDK encodes as BigInt for v.int64())
    /// - Parameter durationMinutes: Duration in minutes (plain Int — SDK encodes as BigInt)
    /// - Parameter rrule: Optional RRULE string for recurring events (e.g. "FREQ=DAILY")
    func createEvent(
        title: String,
        start: Date,
        durationMinutes: Int,
        isAllDay: Bool = false,
        rrule: String? = nil
    ) async throws {
        let startMs = Int(start.timeIntervalSince1970 * 1000)
        // ConvexEncodable? is required — Int, String, Bool all conform
        var args: [String: ConvexEncodable?] = [
            "calendarId": "personal",
            "title": title,
            "start": startMs,               // Swift Int → SDK encodes as BigInt for v.int64()
            "duration": durationMinutes,    // Swift Int → SDK encodes as BigInt for v.int64()
            "timezone": TimeZone.current.identifier,
            "isAllDay": isAllDay
        ]
        if let rrule {
            args["rrule"] = rrule
        }
        try await convex.mutation("events:create", with: args)
    }

    /// Updates an existing event. Only provided fields are updated (partial patch).
    func updateEvent(
        id: String,
        title: String? = nil,
        start: Date? = nil,
        durationMinutes: Int? = nil
    ) async throws {
        var args: [String: ConvexEncodable?] = ["id": id]
        if let title { args["title"] = title }
        if let start { args["start"] = Int(start.timeIntervalSince1970 * 1000) }
        if let d = durationMinutes { args["duration"] = d }
        try await convex.mutation("events:update", with: args)
    }

    /// Removes an event permanently. A confirmationDialog should be shown before calling this.
    func deleteEvent(id: String) async throws {
        let args: [String: ConvexEncodable?] = ["id": id]
        try await convex.mutation("events:remove", with: args)
    }

    // MARK: - Recurrence Mutations

    /// Adds an exception date to a recurring event's master, hiding that occurrence.
    /// For virtual occurrences, resolves to the master event ID automatically.
    func addExceptionDate(event: LoomEvent, occurrenceDate: Date) async throws {
        let masterId = event.masterEventId ?? event._id

        // Find the master event to get current exception dates
        guard let master = events.first(where: { $0._id == masterId }) else { return }

        // Parse existing exceptions, append new one, re-encode
        var exceptions = master.parsedExceptionDates
        let occMs = Int(occurrenceDate.timeIntervalSince1970 * 1000)
        exceptions.append(occMs)

        let jsonData = try JSONEncoder().encode(exceptions)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"

        let args: [String: ConvexEncodable?] = [
            "id": masterId,
            "exceptionDates": jsonString
        ]
        try await convex.mutation("events:update", with: args)
    }

    /// Deletes the entire recurring series. Resolves virtual occurrences to master ID.
    func deleteRecurringSeries(event: LoomEvent) async throws {
        let targetId = event.masterEventId ?? event._id
        try await deleteEvent(id: targetId)
    }

    /// Edits a single occurrence: creates a standalone event copy + adds exception to master.
    /// The new standalone event has no rrule and links back via recurrenceGroupId.
    func editSingleOccurrence(
        masterEvent: LoomEvent,
        occurrenceStartMs: Int,
        title: String,
        start: Date,
        durationMinutes: Int,
        isAllDay: Bool
    ) async throws {
        let masterId = masterEvent.masterEventId ?? masterEvent._id

        // 1. Create standalone event (no rrule) with edited fields
        let startMs = Int(start.timeIntervalSince1970 * 1000)
        let args: [String: ConvexEncodable?] = [
            "calendarId": masterEvent.calendarId,
            "title": title,
            "start": startMs,
            "duration": durationMinutes,
            "timezone": masterEvent.timezone,
            "isAllDay": isAllDay,
            "recurrenceGroupId": masterId
        ]
        try await convex.mutation("events:create", with: args)

        // 2. Add exception date to master for the original occurrence
        let occDate = Date(timeIntervalSince1970: TimeInterval(occurrenceStartMs) / 1000)
        try await addExceptionDate(event: masterEvent, occurrenceDate: occDate)
    }

    // MARK: - Highlight Feedback

    /// Highlights an event briefly (2 seconds) to draw attention after a Loom action mutation.
    /// Views observe highlightedEventId to apply a visual emphasis.
    func flashHighlight(eventId: String) {
        highlightedEventId = eventId
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                self.highlightedEventId = nil
            }
        }
    }

    // MARK: - Navigation

    /// Navigates the calendar view to the given date (e.g., after Loom creates an event).
    func navigateToDate(_ date: Date) {
        selectedDate = date
    }

    /// Move forward by one unit (day/week/month) based on current viewMode.
    func navigateForward() {
        let cal = Calendar.current
        switch viewMode {
        case .day:   selectedDate = cal.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        case .week:  selectedDate = cal.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
        case .month: selectedDate = cal.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
        }
    }

    /// Move backward by one unit (day/week/month) based on current viewMode.
    func navigateBackward() {
        let cal = Calendar.current
        switch viewMode {
        case .day:   selectedDate = cal.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        case .week:  selectedDate = cal.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
        case .month: selectedDate = cal.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
        }
    }

    /// Formatted title string for the toolbar based on current viewMode and selectedDate.
    var toolbarTitle: String {
        let formatter = DateFormatter()
        switch viewMode {
        case .day:
            formatter.dateFormat = "EEEE, MMMM d, yyyy"
        case .week:
            formatter.dateFormat = "MMMM yyyy"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
        }
        return formatter.string(from: selectedDate)
    }
}
