import ConvexMobile

// Matches convex/schema.ts `chat_messages` table definition exactly.
// CRITICAL: All v.int64() schema fields use @ConvexInt var (NOT let).
// Source: https://docs.convex.dev/client/swift/data-types
struct ChatMessage: Decodable, Identifiable {
    let _id: String
    let role: String                   // "user" or "assistant" (v.union literal)
    let content: String
    @ConvexInt var sentAt: Int         // UTC milliseconds — v.int64() // MARK: ConvexInt required

    // Identifiable conformance — matches LoomEvent and LoomTask pattern.
    // var id avoids CodingKeys issues with @ConvexInt wrapper properties.
    var id: String { _id }
}
