import Foundation
import ConvexMobile

// Matches convex/schema.ts `chat_messages` table definition exactly.
// CRITICAL: All v.int64() schema fields use @ConvexInt var (NOT let).
// Source: https://docs.convex.dev/client/swift/data-types
struct ChatMessage: Decodable, Identifiable {
    let _id: String
    let role: String                   // "user", "assistant", or "pending_action"
    let content: String
    @ConvexInt var sentAt: Int         // UTC milliseconds — v.int64() // MARK: ConvexInt required

    // Action fields — present on pending_action messages, nil for regular messages.
    let action: String?                // JSON string of the LoomAction payload
    let actionStatus: String?          // "pending", "confirmed", "cancelled", or "undone"

    // Identifiable conformance — matches LoomEvent and LoomTask pattern.
    // var id avoids CodingKeys issues with @ConvexInt wrapper properties.
    var id: String { _id }

    // True when this message is a pending action awaiting user confirmation.
    var isPendingAction: Bool {
        role == "pending_action" && actionStatus == "pending"
    }

    // Decode the JSON action string into a typed LoomAction struct.
    var decodedAction: LoomAction? {
        guard let action = action,
              let data = action.data(using: .utf8)
        else { return nil }
        return try? JSONDecoder().decode(LoomAction.self, from: data)
    }
}
