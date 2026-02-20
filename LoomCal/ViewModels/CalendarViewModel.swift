import SwiftUI
import ConvexMobile

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

    /// True while waiting for first subscription result
    @Published var isLoading: Bool = true

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
    func events(for date: Date) -> [LoomEvent] {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        return events.filter { event in
            let ms = TimeInterval(event.start) / 1000
            let d = Date(timeIntervalSince1970: ms)
            return d >= start && d < end
        }
    }

    /// All-day events for the given date.
    func allDayEvents(for date: Date) -> [LoomEvent] {
        events(for: date).filter { $0.isAllDay }
    }

    /// Timed (non-all-day) events for the given date.
    func timedEvents(for date: Date) -> [LoomEvent] {
        events(for: date).filter { !$0.isAllDay }
    }

    // MARK: - CRUD Mutations

    /// Creates a new event in Convex.
    /// - Parameter start: Event start time (converted to ms Int — SDK encodes as BigInt for v.int64())
    /// - Parameter durationMinutes: Duration in minutes (plain Int — SDK encodes as BigInt)
    func createEvent(
        title: String,
        start: Date,
        durationMinutes: Int,
        isAllDay: Bool = false
    ) async throws {
        let startMs = Int(start.timeIntervalSince1970 * 1000)
        // ConvexEncodable? is required — Int, String, Bool all conform
        let args: [String: ConvexEncodable?] = [
            "calendarId": "personal",
            "title": title,
            "start": startMs,               // Swift Int → SDK encodes as BigInt for v.int64()
            "duration": durationMinutes,    // Swift Int → SDK encodes as BigInt for v.int64()
            "timezone": TimeZone.current.identifier,
            "isAllDay": isAllDay
        ]
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
}
