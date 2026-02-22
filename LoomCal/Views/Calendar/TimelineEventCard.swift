import SwiftUI

// MARK: - HighlightPulseModifier

/// Applies a pulsing accent border overlay when isHighlighted is true.
/// Used by TimelineEventCard and TaskRowView to visually feedback after Loom mutations.
struct HighlightPulseModifier: ViewModifier {
    let isHighlighted: Bool
    @State private var pulseOpacity: Double = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor, lineWidth: 2)
                        .opacity(pulseOpacity)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.5).repeatCount(3, autoreverses: true)) {
                                pulseOpacity = 1.0
                            }
                        }
                }
            }
    }
}

extension View {
    /// Applies a pulsing accent-color border when active is true.
    /// Called on TimelineEventCard and TaskRowView after Loom mutations.
    func highlightPulse(active: Bool) -> some View {
        modifier(HighlightPulseModifier(isHighlighted: active))
    }
}

/// Fantastical-inspired event card for the day timeline.
/// Displays event title and formatted 12-hour start time.
/// Regular events: blue accent bar + blue background.
/// Time-blocked events (isTimeBlock: true): orange accent bar + orange background + task icon.
/// Supports long-press + drag gesture for drag-to-move functionality.
struct TimelineEventCard: View {
    let event: LoomEvent
    /// True when this event is a time-block linked to a task (event.taskId != nil).
    /// Changes styling to orange to visually distinguish from regular blue events.
    var isTimeBlock: Bool = false
    /// True when this event matches CalendarViewModel.highlightedEventId — triggers pulse animation.
    var isHighlighted: Bool = false
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

    /// Accent bar color — gold for time-blocks, blue-gray for regular events
    private var accentColor: Color {
        isTimeBlock ? LoomColors.timeBlockAccent.opacity(0.8) : LoomColors.eventAccent
    }

    /// Background fill color
    private var backgroundColor: Color {
        isTimeBlock ? LoomColors.timeBlockAccent.opacity(isDragging ? 0.18 : 0.08)
                    : LoomColors.eventAccent.opacity(isDragging ? 0.25 : 0.15)
    }

    var body: some View {
        Button(action: {
            // Only fire tap when not in drag mode
            if !isDragging {
                onTap()
            }
        }) {
            HStack(spacing: 0) {
                // Leading accent bar — orange for time-blocks, blue for regular
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 4)

                // Event content
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        // Task icon for time-blocked events
                        if isTimeBlock {
                            Image(systemName: "checkmark.square")
                                .font(.system(size: 10))
                                .foregroundStyle(LoomColors.timeBlockAccent.opacity(0.8))
                        }

                        Text(event.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }

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
                    .fill(backgroundColor)
            )
            .shadow(color: .black.opacity(isDragging ? 0.18 : 0.08), radius: isDragging ? 8 : 4, y: 2)
            .opacity(isDragging ? 0.8 : 1.0)
        }
        .buttonStyle(.plain)
        .highlightPulse(active: isHighlighted)
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
    VStack(spacing: 16) {
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

        TimelineEventCard(event: sampleEvent, isTimeBlock: true)
            .frame(width: 280, height: 60)
    }
    .padding()
}
