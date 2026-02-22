import Foundation

// LoomAction represents an action payload produced by the Loom AI assistant.
// The payload is serialized as a JSON string in the ChatMessage.action field
// and decoded on-device for user confirmation before executing the mutation.
struct LoomAction: Codable, Equatable {
    let type: String              // "create_event", "update_event", "delete_event",
                                  // "create_task", "update_task", "delete_task"
    let displaySummary: String    // Human-readable summary shown in the confirmation card
    let payload: [String: ActionValue]
    let previousValues: [String: ActionValue]?  // For update actions — shows what changed

    // Flexible value type — payload fields can be String, Int, or Bool.
    // Bool must be checked first; JSON booleans would otherwise decode as Int (0/1).
    enum ActionValue: Codable, Equatable {
        case string(String)
        case int(Int)
        case bool(Bool)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let boolVal = try? container.decode(Bool.self) {
                self = .bool(boolVal)
            } else if let intVal = try? container.decode(Int.self) {
                self = .int(intVal)
            } else if let strVal = try? container.decode(String.self) {
                self = .string(strVal)
            } else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot decode ActionValue — expected Bool, Int, or String"
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let v): try container.encode(v)
            case .int(let v):    try container.encode(v)
            case .bool(let v):   try container.encode(v)
            }
        }

        var stringValue: String? {
            if case .string(let v) = self { return v }
            return nil
        }

        var intValue: Int? {
            if case .int(let v) = self { return v }
            if case .string(let v) = self { return Int(v) }
            return nil
        }

        var boolValue: Bool? {
            if case .bool(let v) = self { return v }
            return nil
        }
    }

    // MARK: - Convenience classifiers

    /// True for event-related actions (create/update/delete_event)
    var isEventAction: Bool { type.contains("event") }

    /// True for task-related actions (create/update/delete_task)
    var isTaskAction: Bool { type.contains("task") }

    var isCreate: Bool { type.hasPrefix("create_") }
    var isUpdate: Bool { type.hasPrefix("update_") }
    var isDelete: Bool { type.hasPrefix("delete_") }
}
