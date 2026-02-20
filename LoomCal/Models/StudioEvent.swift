import ConvexMobile

// Matches convex/schema.ts `studio_events` table definition exactly.
// Studio events are read-only in Convex — source of truth is Supabase.
// CRITICAL: All v.int64() schema fields use @ConvexInt var (NOT let).
// Source: https://docs.convex.dev/client/swift/data-types
struct StudioEvent: Decodable {
    let _id: String
    let calendarId: String             // fixed value: "studio"
    let title: String
    @ConvexInt var start: Int          // UTC milliseconds — v.int64() // MARK: ConvexInt required
    @ConvexInt var duration: Int       // minutes — v.int64()          // MARK: ConvexInt required
    let timezone: String
    let isAllDay: Bool
    @ConvexInt var lastSyncedAt: Int   // UTC ms — when synced from Supabase // MARK: ConvexInt required
}
