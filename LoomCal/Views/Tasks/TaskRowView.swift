import SwiftUI

/// TaskRowView renders a Things 3-style compact task row.
/// Priority left-edge bar (3pt wide), completion circle button,
/// title with strikethrough-on-complete, and due date chip.
struct TaskRowView: View {
    let task: LoomTask
    var onComplete: () -> Void
    var onTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Priority left edge bar
            Rectangle()
                .fill(task.priorityColor)
                .frame(width: 3)

            // Completion circle button
            Button {
                onComplete()
            } label: {
                Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.completed ? .secondary : task.priorityColor)
                    .font(.system(size: 20))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            // Title
            Text(task.title)
                .font(.body)
                .strikethrough(task.completed)
                .foregroundStyle(task.completed ? .secondary : .primary)
                .lineLimit(2)

            Spacer()

            // Due date chip
            if let dateString = task.dueDateFormatted {
                Text(dateString)
                    .font(.caption2)
                    .foregroundStyle(task.isOverdue ? .red : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(task.isOverdue ? Color.red.opacity(0.1) : Color.gray.opacity(0.15))
                    )
                    .padding(.trailing, 12)
            }
        }
        .background(.background)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}
