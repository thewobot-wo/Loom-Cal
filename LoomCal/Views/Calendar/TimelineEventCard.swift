import SwiftUI

/// Fantastical-inspired event card for the day timeline.
/// Displays event title and formatted 12-hour start time.
/// Visual style: rounded rectangle, blue tint, left accent bar, subtle shadow.
/// Supports long-press + drag gesture for drag-to-move functionality.
struct TimelineEventCard: View {
    let event: LoomEvent
    var onTap: () -> Void = {}
    /// Called with vertical point delta (positive = down, negative = up) on drag end.
    var onDragMove: ((CGFloat) -> Void)?

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"   // 12-hour format per locked decision
        return f
    }()

    private var startDate: Date {
        // LoomEvent.start is Int, milliseconds since epoch
        Date(timeIntervalSince1970: TimeInterval(event.start) / 1000)
    }

    private var formattedTime: String {
        Self.timeFormatter.string(from: startDate)
    }

    var body: some View {
        Button(action: {
            // Only fire tap when not in drag mode
            if !isDragging {
                onTap()
            }
        }) {
            HStack(spacing: 0) {
                // Leading blue accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
                    .frame(width: 4)

                // Event content
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(formattedTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

                Spacer(minLength: 0)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(isDragging ? 0.25 : 0.15))
            )
            .shadow(color: .black.opacity(isDragging ? 0.18 : 0.08), radius: isDragging ? 8 : 4, y: 2)
            .opacity(isDragging ? 0.8 : 1.0)
        }
        .buttonStyle(.plain)
        .offset(y: dragOffset)
        .gesture(
            // Long-press activates drag mode to prevent accidental drags.
            // After hold, drag gesture tracks vertical movement.
            LongPressGesture(minimumDuration: 0.3)
                .sequenced(before: DragGesture(minimumDistance: 1, coordinateSpace: .global))
                .onChanged { value in
                    switch value {
                    case .first:
                        // Long-press recognized — activate drag mode
                        isDragging = true
                    case .second(true, let drag?):
                        // Dragging — update visual offset
                        isDragging = true
                        dragOffset = drag.translation.height
                    default:
                        break
                    }
                }
                .onEnded { value in
                    if case .second(true, let drag?) = value {
                        // Drag completed — notify parent with total vertical delta
                        onDragMove?(drag.translation.height)
                    }
                    // Reset drag state
                    withAnimation(.easeOut(duration: 0.15)) {
                        dragOffset = 0
                        isDragging = false
                    }
                }
        )
    }
}

#Preview {
    // Approximate 60 minutes from now in ms
    let nowMs = Int(Date().timeIntervalSince1970 * 1000)
    let sampleEvent = try! JSONDecoder().decode(LoomEvent.self, from: """
    {
      "_id": "preview-id",
      "calendarId": "personal",
      "title": "Team Standup",
      "start": \(nowMs),
      "duration": 30,
      "timezone": "America/New_York",
      "isAllDay": false
    }
    """.data(using: .utf8)!)

    TimelineEventCard(event: sampleEvent)
        .frame(width: 280, height: 60)
        .padding()
}
