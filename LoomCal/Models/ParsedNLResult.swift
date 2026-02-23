import ConvexMobile
import Foundation

/// Matches the Convex `parse_requests` table document returned by `nlParse:getResult`.
/// Used by NLParseService to receive Loom-parsed NL input results.
struct ParsedNLResult: Decodable {
    let _id: String
    let requestId: String
    let text: String
    let type: String                        // "event" or "task"
    let status: String                      // "pending", "complete", "error"
    let result: String?                     // JSON string of parsed fields
    @ConvexInt var createdAt: Int           // UTC milliseconds

    // MARK: - Decoded Result Helpers

    /// Decode the `result` JSON string into structured event fields.
    var eventFields: ParsedEventFields? {
        guard let result, let data = result.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ParsedEventFields.self, from: data)
    }

    /// Decode the `result` JSON string into structured task fields.
    var taskFields: ParsedTaskFields? {
        guard let result, let data = result.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ParsedTaskFields.self, from: data)
    }
}

/// Structured event fields parsed from NL input by the bridge via OpenClaw.
struct ParsedEventFields: Decodable {
    let title: String
    let start: String                       // ISO 8601 datetime
    let duration: Int?                      // minutes, default 60
    let isAllDay: Bool?                     // default false
}

/// Structured task fields parsed from NL input by the bridge via OpenClaw.
struct ParsedTaskFields: Decodable {
    let title: String
    let priority: String?                   // "high", "medium", "low"
    let dueDate: String?                    // ISO 8601 datetime or null
    let hasDueTime: Bool?                   // default false
}
