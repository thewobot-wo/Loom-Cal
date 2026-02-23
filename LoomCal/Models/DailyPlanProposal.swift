import Foundation

/// A daily plan proposal from Loom containing multiple proposed time blocks.
/// Decoded from the ChatMessage.action JSON string when type is "daily_plan".
struct DailyPlanProposal: Codable {
    let type: String              // "daily_plan"
    let displaySummary: String
    let payload: PlanPayload

    struct PlanPayload: Codable {
        let blocks: [PlannedBlock]
    }
}

/// A single proposed time block within a daily plan.
struct PlannedBlock: Codable, Identifiable {
    var id: String { "\(title)-\(start)" }

    let title: String
    let start: Int       // UTC milliseconds (bridge normalizes from ISO)
    let duration: Int    // minutes

    // Custom Codable: bridge normalizes values to strings, so handle both String and Int
    enum CodingKeys: String, CodingKey {
        case title, start, duration
    }

    init(title: String, start: Int, duration: Int) {
        self.title = title
        self.start = start
        self.duration = duration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)

        // Handle both String-encoded and raw Int for start
        if let intVal = try? container.decode(Int.self, forKey: .start) {
            start = intVal
        } else if let strVal = try? container.decode(String.self, forKey: .start),
                  let parsed = Int(strVal) {
            start = parsed
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .start, in: container,
                debugDescription: "start must be Int or numeric String"
            )
        }

        // Handle both String-encoded and raw Int for duration
        if let intVal = try? container.decode(Int.self, forKey: .duration) {
            duration = intVal
        } else if let strVal = try? container.decode(String.self, forKey: .duration),
                  let parsed = Int(strVal) {
            duration = parsed
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .duration, in: container,
                debugDescription: "duration must be Int or numeric String"
            )
        }
    }

    // MARK: - Computed Helpers

    var startDate: Date {
        Date(timeIntervalSince1970: TimeInterval(start) / 1000)
    }

    var endDate: Date {
        startDate.addingTimeInterval(TimeInterval(duration) * 60)
    }

    var durationFormatted: String {
        if duration < 60 { return "\(duration) min" }
        if duration % 60 == 0 { return "\(duration / 60) hr" }
        return "\(duration / 60) hr \(duration % 60) min"
    }
}
