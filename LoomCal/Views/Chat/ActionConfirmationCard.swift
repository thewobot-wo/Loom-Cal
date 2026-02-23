import SwiftUI

// MARK: - ActionConfirmationCard

/// Inline confirmation card rendered in the chat stream for pending_action messages.
/// Stays in the chat bubble stream (not a modal/sheet) per locked design decision.
/// Shows action type icon, summary, type-specific detail fields, and Confirm/Cancel buttons.
/// After confirmation or cancellation, buttons are replaced by a status label.
struct ActionConfirmationCard: View {
    let message: ChatMessage
    var onConfirm: () -> Void = {}
    var onCancel: () -> Void = {}

    private var action: LoomAction? {
        message.decodedAction
    }

    private var actionStatus: String {
        message.actionStatus ?? "pending"
    }

    var body: some View {
        // Resolved/cancelled cards collapse to a single compact line
        if actionStatus != "pending" {
            collapsedCard
        } else {
            expandedCard
        }
    }

    /// Full card with details and Confirm/Cancel buttons — shown only while pending.
    private var expandedCard: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                if let action = action {
                    actionHeader(action: action)

                    Text(action.displaySummary)
                        .font(.body)
                        .foregroundStyle(.primary)

                    actionDetails(action: action)

                    actionButtons
                } else {
                    Text(message.content)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.leading, 8)
            .padding(.trailing, 60)

            Spacer(minLength: 0)
        }
    }

    /// Compact single-line summary after confirmation/cancellation — keeps chat clean.
    private var collapsedCard: some View {
        HStack(alignment: .top, spacing: 0) {
            HStack(spacing: 6) {
                statusIcon
                Text(action?.displaySummary ?? message.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.05))
            )
            .padding(.leading, 8)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch actionStatus {
        case "confirmed":
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case "cancelled":
            Image(systemName: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        case "undone":
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        default:
            EmptyView()
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func actionHeader(action: LoomAction) -> some View {
        HStack(spacing: 6) {
            Image(systemName: headerIcon(for: action.type))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(headerColor(for: action.type))

            Text(actionTypeLabel(for: action.type))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(headerColor(for: action.type))
                .textCase(.uppercase)
        }
    }

    private func headerIcon(for type: String) -> String {
        switch type {
        case "create_event":  return "calendar.badge.plus"
        case "update_event":  return "pencil"
        case "delete_event":  return "trash"
        case "create_task":   return "checkmark.circle"
        case "update_task":   return "pencil.circle"
        case "delete_task":   return "trash.circle"
        default:              return "bolt"
        }
    }

    private func headerColor(for type: String) -> Color {
        switch type {
        case "delete_event", "delete_task": return .red
        case "update_event", "update_task": return .orange
        default: return .accentColor
        }
    }

    private func actionTypeLabel(for type: String) -> String {
        switch type {
        case "create_event":  return "Create Event"
        case "update_event":  return "Update Event"
        case "delete_event":  return "Delete Event"
        case "create_task":   return "Create Task"
        case "update_task":   return "Update Task"
        case "delete_task":   return "Delete Task"
        default:              return "Action"
        }
    }

    // MARK: - Details

    @ViewBuilder
    private func actionDetails(action: LoomAction) -> some View {
        switch action.type {

        case "create_event":
            VStack(alignment: .leading, spacing: 4) {
                if let title = action.payload["title"]?.stringValue {
                    detailRow(icon: "calendar", label: title)
                }
                if let startMs = action.payload["start"]?.intValue,
                   let dateStr = formatActionDate(startMs) {
                    detailRow(icon: "clock", label: dateStr)
                }
                if let duration = action.payload["duration"]?.intValue {
                    detailRow(icon: "timer", label: formatDuration(duration))
                }
                if let location = action.payload["location"]?.stringValue {
                    detailRow(icon: "mappin", label: location)
                }
            }

        case "create_task":
            VStack(alignment: .leading, spacing: 4) {
                if let title = action.payload["title"]?.stringValue {
                    detailRow(icon: "checkmark.circle", label: title)
                }
                if let priority = action.payload["priority"]?.stringValue {
                    detailRow(icon: "flag", label: priority.capitalized + " priority")
                }
                if let dueDateMs = action.payload["dueDate"]?.intValue,
                   let dateStr = formatActionDate(dueDateMs) {
                    detailRow(icon: "calendar", label: "Due: " + dateStr)
                }
            }

        case "update_event", "update_task":
            // Before/after diff — show fields that changed
            if let prev = action.previousValues, !prev.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(diffFields(payload: action.payload, previous: prev), id: \.key) { field in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(field.key.fieldLabel)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                Text(field.oldDisplay)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .strikethrough()
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(field.newDisplay)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            } else {
                // No diff available — just show the summary
                EmptyView()
            }

        case "delete_event", "delete_task":
            if let title = action.payload["title"]?.stringValue {
                detailRow(icon: "trash", label: title)
                    .foregroundStyle(.red)
            }

        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func detailRow(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Diff helpers

    private struct DiffField: Identifiable {
        let id = UUID()
        let key: String
        let oldDisplay: String
        let newDisplay: String
    }

    private func diffFields(
        payload: [String: LoomAction.ActionValue],
        previous: [String: LoomAction.ActionValue]
    ) -> [DiffField] {
        var result: [DiffField] = []
        for (key, newVal) in payload {
            guard let oldVal = previous[key], oldVal != newVal else { continue }
            // Skip internal/non-display fields
            guard key != "id" else { continue }
            let oldDisplay = displayValue(for: key, value: oldVal)
            let newDisplay = displayValue(for: key, value: newVal)
            result.append(DiffField(key: key, oldDisplay: oldDisplay, newDisplay: newDisplay))
        }
        return result
    }

    private func displayValue(for key: String, value: LoomAction.ActionValue) -> String {
        switch key {
        case "start", "dueDate":
            if let ms = value.intValue, let dateStr = formatActionDate(ms) {
                return dateStr
            }
            return value.stringValue ?? "—"
        case "duration":
            if let mins = value.intValue {
                return formatDuration(mins)
            }
            return value.stringValue ?? "—"
        case "isAllDay", "hasDueTime", "completed":
            if let b = value.boolValue {
                return b ? "Yes" : "No"
            }
            return value.stringValue ?? "—"
        default:
            return value.stringValue ?? "\(value.intValue.map { String($0) } ?? "—")"
        }
    }

    // MARK: - Buttons / Status

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                onConfirm()
            } label: {
                Label("Confirm", systemImage: "checkmark")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)

            Button {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                onCancel()
            } label: {
                Text("Cancel")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    // statusLabel removed — collapsed cards handle resolved states

    // MARK: - Date / Duration Formatters

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    /// Converts millisecond timestamp Int to a readable date string.
    private func formatActionDate(_ ms: Int) -> String? {
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        return Self.dateFormatter.string(from: date)
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else if minutes % 60 == 0 {
            return "\(minutes / 60) hr"
        } else {
            return "\(minutes / 60) hr \(minutes % 60) min"
        }
    }
}

// MARK: - String Extension for field display labels

private extension String {
    var fieldLabel: String {
        switch self {
        case "title":     return "Title"
        case "start":     return "Start time"
        case "duration":  return "Duration"
        case "dueDate":   return "Due date"
        case "priority":  return "Priority"
        case "completed": return "Completed"
        case "hasDueTime": return "Has time"
        case "isAllDay":  return "All day"
        case "location":  return "Location"
        case "notes":     return "Notes"
        default:          return self
        }
    }
}
