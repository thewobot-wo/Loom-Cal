import SwiftUI
import ConvexMobile

// Matches convex/schema.ts `tasks` table definition exactly.
// CRITICAL: All v.int64() schema fields use @ConvexInt var (NOT let).
// Named LoomTask (not Task) to avoid collision with Swift's built-in Task type.
// Source: https://docs.convex.dev/client/swift/data-types
struct LoomTask: Decodable, Identifiable {
    let _id: String
    var id: String { _id }           // Identifiable — matches LoomEvent pattern
    let title: String
    @OptionalConvexInt var dueDate: Int?   // UTC milliseconds — @OptionalConvexInt required for v.optional(v.int64())
    let hasDueTime: Bool                   // true when dueDate includes time component
    let priority: String                   // "high" | "medium" | "low"
    let completed: Bool
    let notes: String?                     // markdown plain text
    let attachments: [String]?
}

extension LoomTask {
    var priorityColor: Color {
        switch priority {
        case "high":   return .red
        case "medium": return .yellow
        default:       return Color.blue.opacity(0.6)  // low or unrecognized
        }
    }

    var isOverdue: Bool {
        guard !completed, let ms = dueDate else { return false }
        return Date(timeIntervalSince1970: TimeInterval(ms) / 1000) < Date()
    }

    var dueDateAsDate: Date? {
        guard let ms = dueDate else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
    }

    var dueDateFormatted: String? {
        guard let date = dueDateAsDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = hasDueTime ? "MMM d, h:mm a" : "MMM d"
        return formatter.string(from: date)
    }
}
