import ConvexMobile

// Matches convex/schema.ts `tasks` table definition exactly.
// CRITICAL: All v.int64() schema fields use @ConvexInt var (NOT let).
// Named LoomTask (not Task) to avoid collision with Swift's built-in Task type.
// Source: https://docs.convex.dev/client/swift/data-types
struct LoomTask: Decodable {
    let _id: String
    let title: String
    @OptionalConvexInt var dueDate: Int?    // UTC milliseconds — v.optional(v.int64()) // MARK: ConvexInt required
    let flagged: Bool                        // boolean flag — no priority tiers (user decision)
    let completed: Bool
    let notes: String?                       // markdown plain text
    let attachments: [String]?
}
