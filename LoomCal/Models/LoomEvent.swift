import ConvexMobile
import Foundation

// Matches convex/schema.ts `events` table definition exactly.
// CRITICAL: All v.int64() schema fields use @ConvexInt var (NOT let).
// @ConvexInt handles BigInt <-> Swift Int round-tripping over the wire.
// Source: https://docs.convex.dev/client/swift/data-types
struct LoomEvent: Decodable, Identifiable {
    let _id: String
    /// Identifiable conformance — required for .sheet(item: $selectedEvent) in ContentView.
    var id: String { _id }
    let calendarId: String
    let title: String
    @ConvexInt var start: Int          // UTC milliseconds — v.int64() // MARK: ConvexInt required
    @ConvexInt var duration: Int       // minutes — v.int64()          // MARK: ConvexInt required
    let timezone: String               // IANA timezone, e.g. "America/New_York"
    let isAllDay: Bool
    let location: String?
    let notes: String?                 // markdown plain text
    let url: String?                   // dedicated meeting link field (not notes)
    let color: String?
    let rrule: String?                 // RRULE recurrence string
    let recurrenceGroupId: String?
    let exceptionDates: String?        // JSON array of UTC ms timestamps, e.g. "[1708819200000]"
    let attachments: [String]?
    let taskId: String?                // non-nil when event is a time-block for a task

    // MARK: - Recurrence Helpers

    /// Whether this event has a recurrence rule.
    var isRecurring: Bool { rrule != nil && !rrule!.isEmpty }

    /// Whether this is a virtual occurrence expanded from a master recurring event.
    /// Virtual IDs contain "_occ_" separator: "{masterId}_occ_{startMs}".
    var isVirtualOccurrence: Bool { _id.contains("_occ_") }

    /// The master event ID for virtual occurrences. Returns nil for non-virtual events.
    var masterEventId: String? {
        guard isVirtualOccurrence else { return nil }
        return String(_id.split(separator: "_occ_").first ?? "")
    }

    /// Parse exceptionDates JSON string into array of UTC millisecond timestamps.
    var parsedExceptionDates: [Int] {
        guard let json = exceptionDates, let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([Int].self, from: data)) ?? []
    }

    /// Parse exceptionDates into Date array for use with RecurrenceRule.
    var exceptionDateValues: [Date] {
        parsedExceptionDates.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
    }

    /// Create a virtual occurrence of this event at a different start time.
    /// The virtual event has a synthetic ID: "{masterId}_occ_{newStartMs}".
    static func virtualOccurrence(of master: LoomEvent, startMs: Int) -> LoomEvent {
        LoomEvent(
            _id: "\(master._id)_occ_\(startMs)",
            calendarId: master.calendarId,
            title: master.title,
            start: startMs,
            duration: master.duration,
            timezone: master.timezone,
            isAllDay: master.isAllDay,
            location: master.location,
            notes: master.notes,
            url: master.url,
            color: master.color,
            rrule: master.rrule,
            recurrenceGroupId: master.recurrenceGroupId,
            exceptionDates: master.exceptionDates,
            attachments: master.attachments,
            taskId: master.taskId
        )
    }
}
