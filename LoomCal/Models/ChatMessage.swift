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

    // Audio fields — present when bridge generated TTS for this message.
    let audioUrl: String?              // Resolved Convex storage URL for TTS audio

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

    // Decode the JSON action string as a daily plan proposal.
    var decodedPlan: DailyPlanProposal? {
        guard let action = action,
              let data = action.data(using: .utf8)
        else { return nil }
        let plan = try? JSONDecoder().decode(DailyPlanProposal.self, from: data)
        // Only return if it's actually a daily_plan type
        return plan?.type == "daily_plan" ? plan : nil
    }

    // True when this message is a daily plan proposal awaiting user approval.
    var isDailyPlan: Bool {
        role == "pending_action" && decodedPlan != nil
    }
}
