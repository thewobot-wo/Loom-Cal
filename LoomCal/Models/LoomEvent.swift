import ConvexMobile

// Matches convex/schema.ts `events` table definition exactly.
// CRITICAL: All v.int64() schema fields use @ConvexInt var (NOT let).
// @ConvexInt handles BigInt <-> Swift Int round-tripping over the wire.
// Source: https://docs.convex.dev/client/swift/data-types
struct LoomEvent: Decodable {
    let _id: String
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
    let attachments: [String]?
}
